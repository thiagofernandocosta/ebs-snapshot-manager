# Terraform config for automatic EBS snapshots

This repo contains a terraform configuration that creates two lambda functions
that will take automatic EBS snapshots at regular intervals.

## Usage

terraform apply

### Configuring your instances to be backed up

Tag any instances you want to be backed up with `Backup = true`.

By default, old backups will be removed after 15 days, to keep them longer, set
another tag: `Retention = 30`, where 30 is the number of days you want to keep
the backups for.
