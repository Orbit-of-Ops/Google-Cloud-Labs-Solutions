# Cloud Speech API 3 Ways: Challenge Lab || [ARC132](https://www.cloudskillsboost.google/focuses/67215?parent=catalog) ||

## Solution [here](https://youtu.be/dGMkeDpM1Js)

### Run the following Commands in CloudShell

### Step 1: Download and Transfer the Script (Cloud Shell)
Run the following commands in your **Cloud Shell**. This will identify your VM's zone, download the automation script from GitHub, and securely copy it into the lab VM:

```bash
export ZONE=$(gcloud compute instances list lab-vm --format 'csv[no-heading](zone)')

curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Cloud%20Speech%20API%203%20Ways%20Challenge%20Lab/arc132.sh

gcloud compute scp arc132.sh lab-vm:~ --project=$DEVSHELL_PROJECT_ID --zone=$ZONE --quiet
```

* Go to `Credentials` from [here](https://console.cloud.google.com/apis/credentials)

* Set Variables & Execute (Inside VM)
Inside your VM terminal, fill in the lab variables below and trigger the script:

```
export API_KEY=
export task_2_file_name=""
export task_3_request_file=""
export task_3_response_file=""
export task_4_sentence=""
export task_4_file=""
export task_5_sentence=""
export task_5_file=""
```

```
sudo chmod +x arc132.sh
./arc132.sh
```

### Congratulations 🎉 for completing the Lab !

##### *You Have Successfully Demonstrated Your Skills And Determination.*

#### *Well done!*


# <img src="../logo.png" alt="Orbit of Ops Logo" width="45" align="center"> Orbit of Ops
