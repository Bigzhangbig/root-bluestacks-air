#!/boot/bin/sh
#set -x

BSTCONF_PROP='/.bstconf.prop'
SEED_FOR_DIGEST=""
MD5_DIGEST=""

log_echo()
{
    echo "$@" > /dev/kmsg
}
exec >/dev/kmsg 2>/dev/kmsg

populate_bst_conf()
{
    log_echo "Running bstconf binary, awk: `alias awk`"
    oldIFS="$IFS"
    IFS=$' '
    result=`/boot/bin/bstconf | tee cache/foo.txt`
    #log_echo "Size of foo.txt"
    #log_echo `ls -al cache/foo.txt`
    #log_echo "tailf cache/foo.txt"
    #tail -5 cache/foo.txt > /dev/kmsg
    rm -f cache/foo.txt
    log_echo ""
    rm -f $BSTCONF_PROP

    export_all=$( echo $result | awk 'BEGIN{FS="="; AWK_BSTCONF_PROP="'$BSTCONF_PROP'"} {

        if (/^#.*/)
        {
            cmd = sprintf("echo This is a comment line %s, so ignoring > /dev/kmsg", $0);
            system(cmd);
            print $0 >> AWK_BSTCONF_PROP
            next;
        }

        temp_prop=$0;

        gsub(/\./, "_", $1);
        prop_name=toupper($1);
        prop_value=$2;
        if(! prop_name)
        {
            cmd = sprintf("echo invalid prop_name %s is unset > /dev/kmsg", $0);
            system(cmd);
            next;
        }
        if(prop_value=="")
        {
            cmd = sprintf("echo invalid prop_value for %s is unset > /dev/kmsg", prop_name);
            system(cmd);
            next;
        }

        prop_name_value=sprintf("export %s=\"%s\";", prop_name, prop_value);
        print temp_prop >> AWK_BSTCONF_PROP
        prop_all=prop_all prop_name_value;

    }END{print prop_all; close(AWK_BSTCONF_PROP);}')

    eval $export_all

    #awk '{print}' $BSTCONF_PROP
    #env
    IFS="$oldIFS"
    #log_echo "Printing file $BSTCONF_PROP"
    #log_echo `cat $BSTCONF_PROP`
}

# Main function that will generate all android specific ids.
generate_android_ids()
{
    if [ -z $BST_ANDROID_ID ]; then
        log_echo "<2>ERROR: android_id is empty"
        exit 1
    else
        export SEED_FOR_DIGEST=$BST_ANDROID_ID
        export MD5_DIGEST=`echo -n $SEED_FOR_DIGEST | md5sum | md5sum | cut -c '1-16'`
        generate_serialno
        generate_device_hash_and_imei_id
        generate_bst_simissuerid_and_simsuffix
        generate_subscriber_id
        generate_wifi_mac_addr
        generate_bssid_mac_addr
        generate_bluetooth_addr
        #TODO
        #generate_bst_sim_serial_number
        #     SimSerialNumber len(19-20)
        #     getprop gsm.sim.bstserial(7-8) + BstSimIssuerId(3) + BstSimSuffix(9)  (0-9 digits) 
        #     SampleValue: 8901260795128795224
    fi
}

# length - 12
# type - alphanumeric string
# desc - used to set ro.serialno and ro.boot.serialno
generate_serialno()
{
    local serialno=`echo $BST_ANDROID_ID | cut -c '1-12' | tr 'a-y0-89' 'b-za1-90'`
    log_echo "serialno= $serialno, BST_ANDROID_ID = $BST_ANDROID_ID"
    export BST_SERIALNO=$serialno
    echo "bst.serialno=$serialno" >> $BSTCONF_PROP
    log_echo "Serialno: $BST_SERIALNO"
}

# Device Hash
# length - 32
# type - alphanumeric string
# desc - used to generate mac address 

# IMEI ID
# length - 15
# type - numeric string
# desc - Represents the deviceId 
generate_device_hash_and_imei_id()
{
    local seed=$MD5_DIGEST
    local hash_value=""
    local id=""
    local len=${#seed}
    for i in $(seq 0 $len); do
	    character=${seed:$i:1}
        if [ -z $character ]; then
            continue;
        fi
        hex_val=`/boot/bin/printf "0x%02X" "'$character"`
        tmp=$(( $hex_val & 0xFF ))
        final_val=`/boot/bin/printf '%02X' "$tmp"`
        hash_value="$hash_value$final_val"
        mod=$(( $tmp%10 ))
        id="$id$mod"
    done
    export BST_IMEI_ID=`echo -n $id | cut -c '1-15'`
    export BST_DEVICE_HASH=$hash_value
    echo "bst.imei_id=$BST_IMEI_ID" >> $BSTCONF_PROP
    echo "bst.device_hash=$BST_DEVICE_HASH" >> $BSTCONF_PROP
    log_echo "Hash value: $hash_value, imei_id: $BST_IMEI_ID"
}

# Sim Issuer Id
# length - 3
# type - numeric string
# desc - used to generate sim serial number

# Sim Suffix
# length - 9
# type - numeric string
# desc - used to generate sim serial number and subscriber id
generate_bst_simissuerid_and_simsuffix()
{
    local seed=$MD5_DIGEST
    local len=${#seed}
    local issuer_id=""
    local sim_suffix=""
    local counter=0
    for i in $(seq 0 $len); do
        index=$(( $len - $i ))
        character=${seed:$index:1}
        if [ -z $character ]; then
            continue;
        fi
        counter=$(( $counter + 1 ))
        hex_val=`/boot/bin/printf "0x%02X" "'$character"`
        tmp=$(( $hex_val & 0xFF ))
        val=$(( $tmp%9 + 1 ))
        if [ $counter -lt 10 ]; then
            sim_suffix="$sim_suffix$val"
        elif [ $counter -lt 13 ]; then
            issuer_id="$issuer_id$val"
        else
            break;
        fi
    done
    export BST_SIM_ISSUER_ID=$issuer_id
    export BST_SIM_SUFFIX=$sim_suffix
    echo "bst.sim_issuer_id=$BST_SIM_ISSUER_ID" >> $BSTCONF_PROP
    echo "bst.sim_suffix=$BST_SIM_SUFFIX" >> $BSTCONF_PROP
    log_echo "IssuerId: $issuer_id, sim_suffix: $sim_suffix"
}

# Subscriber Id
# length - 15 (sim_operator + sim suffix)
# type - numeric string
# desc - denotes the subscriberId
generate_subscriber_id()
{
    local sim_operator=`echo $BST_DEVICE_CARRIER_CODE | cut -d '_' -f 2`
    local subscriber_id=$sim_operator
    subscriber_id="$subscriber_id$BST_SIM_SUFFIX"
    if [ ${#subscriber_id} == 14 ]; then
        subscriber_id="$subscriber_id""0"
    fi
    export BST_SUBSCRIBER_ID=$subscriber_id
    echo "bst.subscriber_id=$subscriber_id" >> $BSTCONF_PROP
    log_echo "SubscriberId: $subscriber_id"
}

# MAC addr (helper function)
# length - 17
# type - alphanumeric string
# args - 1 (int value - start offset)
# desc - used to generate wifi mac addr, bssid mac addr
generate_mac_address()
{

    local start_offset=$1
    local hash=$BST_DEVICE_HASH
    local index=$start_offset
    local mac_addr=""
    for i in $(seq 1 12); do
        mac_addr=$mac_addr${hash:$index:1}
        index=$(( $index + 2 ))
        if [ $(( $i%2 )) == 0 ] && [ $i != 12 ]; then
            mac_addr="$mac_addr"":"
        fi
    done
    echo $mac_addr
}

# WIFI MAC addr 
# length - 17
# type - alphanumeric string
# desc - wifi mac addr 
generate_wifi_mac_addr()
{
    local addr=$(generate_mac_address 3)
    export BST_WIFI_MAC_ADDR=$addr
    echo "bst.wifi_mac_addr=$BST_WIFI_MAC_ADDR" >> $BSTCONF_PROP
    log_echo "WifiMacAddr: $addr"
}

# BSSID addr 
# length - 17
# type - alphanumeric string
# desc - bssid mac addr 
generate_bssid_mac_addr()
{
    local addr=$(generate_mac_address 5)
    export BST_BSSID_MAC_ADDR=$addr
    echo "bst.bssid_mac_addr=$BST_BSSID_MAC_ADDR" >> $BSTCONF_PROP
    log_echo "BSSIDMacAddr: $addr"
}

# Bluetooth addr 
# length - 17
# type - alphanumeric string
# desc - bluetooth addr
generate_bluetooth_addr()
{
    local addr=$(generate_mac_address 1)
    addr=`echo $addr | tr 'A-EF0-89' 'B-FA1-90'`
    export BST_BLUETOOTH_ADDR=$addr
    echo "bst.bluetooth_addr=$BST_BLUETOOTH_ADDR" >> $BSTCONF_PROP
    log_echo "BluetoothAddress: $addr"
}



