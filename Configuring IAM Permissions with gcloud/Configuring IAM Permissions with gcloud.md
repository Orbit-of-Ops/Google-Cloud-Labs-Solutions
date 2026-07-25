# Configuring IAM Permissions with gcloud || [GSP647](https://www.cloudskillsboost.google/focuses/7678?parent=catalog) ||

## 🔑 Solution [here](https://youtu.be/HfmuRbcHGgc)

This guide explains how to run the GSP647 lab automation using two scripts hosted on GitHub.


## Important Notes

- Run **Script 01 only in Google Cloud Shell**.
- Run **Script 02 only inside the `centos-clean` VM SSH terminal**.
- Login first with **Username 1** when the script asks.
- Login later with **Username 2** when the script asks.
- Use Incognito/private window for Username 2 login to avoid wrong account selection.
- If Zone 2 is not shown in Qwiklabs, you can press Enter in the V3 script. It will try to auto-detect. If needed, manually enter:

---

## Step 1: Start the Lab

Start the **GSP647** lab on Qwiklabs.

Login to Google Cloud Console using **Username 1** from the Qwiklabs panel.

Open **Google Cloud Shell**.

---

## Step 2: Run the command below in Cloud Shell

```bash
curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Configuring%20IAM%20Permissions%20with%20gcloud/gsp647_01_cloudshell_copy_to_centos_clean_V3.sh
curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Configuring%20IAM%20Permissions%20with%20gcloud/gsp647_02_run_inside_centos_clean_V3.sh
```

## Step 3: Run Script 01 in Cloud Shell

```bash
chmod +x gsp647_01_cloudshell_copy_to_centos_clean_V3.sh gsp647_02_run_inside_centos_clean_V3.sh
./gsp647_01_cloudshell_copy_to_centos_clean_V3.sh
```

This script copies Script 02 into the `centos-clean` VM at:

```text
/tmp/gsp647_02_run_inside_centos_clean_V3.sh
```

---

## Step 4: Open CentOS-clean SSH

Go to:

```text
Google Cloud Console → Compute Engine → VM instances → centos-clean → SSH
```

Inside the `centos-clean` SSH terminal, run:

```bash
/tmp/gsp647_02_run_inside_centos_clean_V3.sh
```

---

## Step 5: Enter Qwiklabs Details

The script will ask for:

```text
Paste Username 1 email from Qwiklabs:
Paste Username 2 email from Qwiklabs:
Paste Project 2 ID from Qwiklabs:
Paste Zone 2 from Qwiklabs if shown, else press ENTER:
```

Example:

```text
Paste Username 1 email from Qwiklabs: student-01-xxxx@qwiklabs.net
Paste Username 2 email from Qwiklabs: student-04-xxxx@qwiklabs.net
Paste Project 2 ID from Qwiklabs: qwiklabs-gcp-02-xxxxxxxxxxxx
Paste Zone 2 from Qwiklabs if shown, else press ENTER:
```

For Zone 2:

- If Qwiklabs shows Zone 2, paste it.
- If not shown, press Enter.
- If auto-detection fails, re-run and enter

---

## Step 6: Complete Browser Authentication

When the script asks for browser login:

1. Press Enter or copy URL.
2. Open the generated login URL.
3. Login with the correct Qwiklabs username.
4. Allow permissions.
5. Copy the verification code.
6. Paste it back into the SSH terminal.

First login with:

```text
Username 1
```

Later, log in with:

```text
Username 2
```

---

## What the Script Completes

The automation performs the following lab tasks:

```text
Create lab-1 in Project 1
Update the default gcloud zone
Create user2 gcloud configuration
Grant Username 2 the viewer role on Project 2
Create a custom DevOps role
Bind iam.serviceAccountUser role to Username 2
Bind custom DevOps role to Username 2
Create lab-2 as Username 2 in Project 2
Create a DevOps service account
Bind service account IAM roles
Create lab-3 with the DevOps service account
SSH into lab-3
Create lab-4 from inside lab-3 using service account permissions
Run final verification
```

---

## Step 7: Check Progress

After the script completes, wait for about 1 minute.

Then go back to Qwiklabs and click all **Check my progress** buttons.

If a task does not mark immediately, wait another 1–2 minutes and click again.

---

# 🎉 Woohoo! You Did It! 🎉

Your hard work and determination paid off! 💻
You've completed the lab. **Way to go!** 🚀

# <img src="../logo.png" alt="Orbit of Ops Logo" width="45" align="center"> Orbit of Ops
