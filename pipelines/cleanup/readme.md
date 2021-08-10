# This pipeline is for cleaning / wiping the avd resources that were created during this PoC using the pipelines

So it will,...:
- ... break AAD sync. Delete sync'ed users.
- ... unregister the desktopvirtualization provider.
- ... remove the service principal
- ... delete avd hostpools, app groups and workspaces.