import boto3
import collections
import datetime

ec = boto3.client('ec2')

def lambda_handler(event, context):
    
    reservations = ec.describe_instances(
        Filters=[
            {'Name': 'tag:Backup', 'Values': ['true', 'yes', '1']},
        ]
    ).get(
        'Reservations', []
    )

    instances = sum(
        [
            [i for i in r['Instances']]
            for r in reservations
        ], [])

    print "Found %d instances that need backing up" % len(instances)

    to_tag = collections.defaultdict(list)

    for instance in instances:
        try:
            retention_days = [
                int(t.get('Value')) for t in instance['Tags']
                if t['Key'] == 'Retention'][0]
        except IndexError:
            retention_days = 15

        for dev in instance['BlockDeviceMappings']:
            if dev.get('Ebs', None) is None:
                continue
            vol_id = dev['Ebs']['VolumeId']
            device_name = dev['DeviceName']
            
            print "Found EBS volume %s, device %s on instance %s" % (
                vol_id, device_name, instance['InstanceId'])

            snap = ec.create_snapshot(
                VolumeId=vol_id,
                Description='Snapshot of volume %s' % vol_id
            )

            to_tag[retention_days].append(snap['SnapshotId'])

            print "Retaining snapshot %s of volume %s from instance %s for %d days" % (
                snap['SnapshotId'],
                vol_id,
                instance['InstanceId'],
                retention_days,
            )
            
            snapshot_name = ''
            group_name    = ''
            
            if 'Tags' in instance:
                for tags in instance['Tags']:
                    if tags["Key"] == 'Name': snapshot_name = tags["Value"]
                    if tags["Key"] == 'Group': group_name = tags["Value"]

            name_group = "%s-SNAPSHOT" %(snapshot_name)
            print "Tagging snapshot with Name: %s" % (name_group)
            
            ec.create_tags(
                Resources=[
                    snap['SnapshotId'],
                ],
                Tags=[
                    {'Key': 'Name', 'Value': name_group},
                    {'Key': 'Group', 'Value': group_name},
                    {'Key': 'Device', 'Value': device_name}
                ]
            )

    for retention_days in to_tag.keys():
        today = datetime.date.today()
        today_string = today.strftime('%Y-%m-%d')
        
        delete_date = today + datetime.timedelta(days=retention_days)
        delete_fmt = delete_date.strftime('%Y-%m-%d')
        
        print "Will delete %d snapshots on %s" % (len(to_tag[retention_days]), delete_fmt)
        ec.create_tags(
            Resources=to_tag[retention_days],
            Tags=[
                {'Key': 'DeleteOn', 'Value': delete_fmt},
                {'Key': 'AutoSnapshot', 'Value': 'true'},
                {'Key': 'CreatedOn', 'Value': today_string}
            ]
        )
