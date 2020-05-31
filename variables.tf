# See https://docs.aws.amazon.com/lambda/latest/dg/tutorial-scheduled-events-schedule-expressions.html
# for how to write schedule expressions
variable "ebs_snapshot_backup_schedule" {
  default = "cron(00 19 * * ? *)"
}

variable "ebs_snapshot_cleanup_schedule" {
  default = "cron(05 19 * * ? *)"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}
