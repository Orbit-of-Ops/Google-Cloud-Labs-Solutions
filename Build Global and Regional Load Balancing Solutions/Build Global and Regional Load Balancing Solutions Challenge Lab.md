# GSP539: Build Global and Regional Load Balancing Solutions - Challenge Lab

[![Orbit of Ops YouTube Channel](https://img.shields.io/badge/YouTube-Orbit_of_Ops-red?logo=youtube&style=for-the-badge)](https://youtu.be/pk0kqI8p1Xc)

Welcome to the **Orbit of Ops** automated solution for the **Build Global and Regional Load Balancing Solutions: Challenge Lab (GSP539)**. 


## ⚠️ Important Prerequisites
Before running any scripts, ensure you have a **completely fresh, newly started lab session**. If you previously had errors in this lab, end it and start a new one to clear the cache.

Identify your assigned regions from the lab instructions panel before you begin:
* **Region A** (e.g., `us-central1`)
* **Region B** (e.g., `us-east4`)

---

## 🚀 Execution Instructions

Open your Google Cloud Shell terminal and execute the following tasks in order. **Do not proceed to the next script until you have secured the points for the current task.**

### Task 1: Regional Internal Proxy NLB
This script provisions the regional internal proxy, firewall rules, and the client VM. It automatically hunts for an available zone to bypass `RESOURCE_POOL_EXHAUSTED` errors.

Run the following commands in Cloud Shell:

    curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Build%20Global%20and%20Regional%20Load%20Balancing%20Solutions/Orbit1.sh
    sudo chmod +x Orbit1.sh
    ./Orbit1.sh

> **Action Required:** When prompted, enter your **Region B**.
> Once the script completes, go to the lab page and click **Check my progress** for Task 1.

---

### Task 2: Global External Application Load Balancer
This script deploys the dual-region Managed Instance Groups, configures the Global ALB, and generates the required SSL certificates.

*Only run this AFTER getting your points for Task 1.*

    curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Build%20Global%20and%20Regional%20Load%20Balancing%20Solutions/Orbit2.sh
    sudo chmod +x Orbit2.sh
    ./Orbit2.sh

> **Action Required:** When prompted, enter your **Region A**. (The script automatically remembers Region B from the first task).
> **Note:** Global Load Balancers take about 3 to 5 minutes to fully propagate. Once the script finishes, wait a few minutes, then click **Check my progress** for Task 2.

---

### Task 3: Test Failover & Global Distribution
This final script verifies the Load Balancer is healthy, simulates a crash on Region A, and forces the automated lab grader to recognize the failover to Region B.

*Only run this AFTER getting your points for Task 2.*

    curl -LO https://github.com/Orbit-of-Ops/Google-Cloud-Labs-Solutions/raw/refs/heads/main/Build%20Global%20and%20Regional%20Load%20Balancing%20Solutions/Orbit3.sh
    sudo chmod +x Orbit3.sh
    ./Orbit3.sh

> **Action Required:** Just sit back and watch! The script will wait for a healthy `HTTP 200 OK` status, trigger the failover, and print the resulting traffic shift to your terminal. 
> Once it completes, click **Check my progress** for Task 3 to claim your 100/100 score.

### If Task 3 fails

In the Google Cloud Console, navigate to Compute Engine > VM instances.

Locate the instance in Region A (based on your log, it is named mig-alb-api-a-lzcg).

Under the Connect column, click the SSH button next to that specific instance. A new browser window will open.

Once the terminal connects, run this exact command to stop the web server:


    sudo systemctl stop nginx

    
Close the SSH window.

Go back to the lab manual and click Check my progress for Task 3.

---

## 🤝 Support the Channel
If this guide helped you conquer the lab, please consider supporting the channel! 
* **Subscribe:** [Orbit of Ops on YouTube](https://www.youtube.com/@OrbitOfOps)
* **Engage:** Like the video, drop a comment, and share it with your fellow cloud engineers!


### Congratulations 🎉 for completing the Lab !

##### *You Have Successfully Demonstrated Your Skills And Determination.*

#### *Well done!*


# <img src="../logo.png" alt="Orbit of Ops Logo" width="45" align="center"> Orbit of Ops
