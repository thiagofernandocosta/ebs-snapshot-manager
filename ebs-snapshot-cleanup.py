import boto3
import datetime

ec = boto3.client('ec2')

"""
This function looks at *all* snapshots that have a "DeleteOn" tag containing
the current day formatted as YYYY-MM-DD.
"""

def lambda_handler(event, context):
    delete_on = datetime.date.today().strftime('%Y-%m-%d')
    filters=[
            {'Name': 'tag:DeleteOn', 'Values': [delete_on]}
        ]
    
    snapshot_response = ec.describe_snapshots(Filters=filters)

    for snap in snapshot_response['Snapshots']:
        print "Deleting snapshot %s" % snap['SnapshotId']
        ec.delete_snapshot(SnapshotId=snap['SnapshotId'])