provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

resource "aws_iam_role" "ebs_backup_role" {
  name = "ebs_backup_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ebs_backup_policy" {
  name = "ebs_backup_policy"
  role = "${aws_iam_role.ebs_backup_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["logs:*"],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:Describe*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:CreateTags",
                "ec2:ModifySnapshotAttribute",
                "ec2:ResetSnapshotAttribute"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}

data "archive_file" "ebs_snapshot_backup_zip" {
  type        = "zip"
  source_file = "${path.module}/ebs-snapshot-backup.py"
  output_path = "${path.module}/ebs-snapshot-backup.zip"
}

resource "aws_lambda_function" "ebs_snapshot_backup" {
  filename         = "${path.module}/ebs-snapshot-backup.zip"
  function_name    = "BackupEC2Snapshots"
  description      = "Automatically backs up instances tagged with backup: true"
  role             = "${aws_iam_role.ebs_backup_role.arn}"
  timeout          = 60
  handler          = "ebs-snapshot-backup.lambda_handler"
  runtime          = "python2.7"
  source_code_hash = "${data.archive_file.ebs_snapshot_backup_zip.output_base64sha256}"
}

data "archive_file" "ebs_snapshot_cleanup_zip" {
  type        = "zip"
  source_file = "${path.module}/ebs-snapshot-cleanup.py"
  output_path = "${path.module}/ebs-snapshot-cleanup.zip"
}

resource "aws_lambda_function" "ebs_snapshot_cleanup" {
  filename         = "${path.module}/ebs-snapshot-cleanup.zip"
  function_name    = "CleanUpEC2Snapshots"
  description      = "Cleans up old EBS backups"
  role             = "${aws_iam_role.ebs_backup_role.arn}"
  timeout          = 60
  handler          = "ebs-snapshot-cleanup.lambda_handler"
  runtime          = "python2.7"
  source_code_hash = "${data.archive_file.ebs_snapshot_cleanup_zip.output_base64sha256}"
}

resource "aws_cloudwatch_event_rule" "ebs_snapshot_backup" {
  name                = "BackupEC2Snapshots"
  description         = "Schedule for ebs snapshot backup"
  schedule_expression = "${var.ebs_snapshot_backup_schedule}"
}

resource "aws_cloudwatch_event_rule" "ebs_snapshot_cleanup" {
  name                = "CleanUpEC2Snapshots"
  description         = "Schedule for ebs snapshot cleanup"
  schedule_expression = "${var.ebs_snapshot_cleanup_schedule}"
}

resource "aws_cloudwatch_event_target" "ebs_snapshot_backup" {
  rule      = "${aws_cloudwatch_event_rule.ebs_snapshot_backup.name}"
  target_id = "BackupEC2Snapshots"
  arn       = "${aws_lambda_function.ebs_snapshot_backup.arn}"
}

resource "aws_cloudwatch_event_target" "ebs_snapshot_cleanup" {
  rule      = "${aws_cloudwatch_event_rule.ebs_snapshot_cleanup.name}"
  target_id = "CleanUpEC2Snapshots"
  arn       = "${aws_lambda_function.ebs_snapshot_cleanup.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_backup" {
  statement_id  = "AllowExecutionFromCloudWatch_ebs_snapshot_backup"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ebs_snapshot_backup.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ebs_snapshot_backup.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_cleanup" {
  statement_id  = "AllowExecutionFromCloudWatch_ebs_snapshot_cleanup"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ebs_snapshot_cleanup.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ebs_snapshot_cleanup.arn}"
}
