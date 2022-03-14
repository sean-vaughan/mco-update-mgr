# Machine Config Operator Update Manager

This simple kustomization-based OpenShift configuration allows machine pool
updates to be applied only after a delay, 20 minutes by default. It is common
that multiple machine config updates will result in multiple machine config pool
node reboot sequences. By delaying the machine pool updates until all machine
config updates have been applied, only a single node reboot sequence will
happen. It's also helpful to have a longer delay so that new cluster resources
may be created and stabilized before node reboots occur. Thus, the default of 20
minutes allows a moderate amount of day-2 operations configuration to be applied
prior to node reboots.

Update the UPDATE_DELAY environment variable in the CronJob to change the update
delay.