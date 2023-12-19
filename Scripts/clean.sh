rm -rf /root/cluster
mkdir /root/cluster
cp __REGISTRYBASE__/downloads/tools/install-config.yaml /root/cluster
./openshift-install create manifests --dir=/root/cluster
./openshift-install create ignition-configs --dir=/root/cluster
cp /root/cluster/*ign /var/www/html/ignition
chmod o+r /var/www/html/ignition/*ign