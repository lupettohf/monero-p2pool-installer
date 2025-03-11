# Monero + P2Pool Automated Installer

This repository contains a bash install script that automates the installation, compilation, and configuration of [Monerod](https://www.getmonero.org/) and [P2Pool](https://github.com/SChernykh/p2pool) on clean Debian/Ubuntu systems. The script supports both x86_64 and ARM64 architectures and sets up the services under dedicated system users for improved security.

> **Note:**  
> This script is intended for use on a clean system running Debian or Ubuntu with **at least 2GB of RAM**. For disk space, you will need **100GB** if you opt for a pruned node, or **300+GB** for a full node.

## Features

-   **Automated Dependencies Installation:** Installs all required dependencies for compiling Monerod and P2Pool.
-   **Latest Source Code Fetching:** Clones the latest source code from the official Monero and P2Pool repositories.
-   **Compilation:** Compiles both Monerod and P2Pool from source.
-   **User Input Prompts:**
    -   Enter your Monero wallet address for P2Pool payouts.
    -   Choose between a pruned or full blockchain download. (Pruned nodes require a minimum of 100GB disk space; full nodes require 300+GB.)
    -   Decide whether the P2Pool stratum port (3333) should be reachable from the internet.
-   **Systemd Service Setup:** Creates systemd unit files for both services, ensuring they run under separate users, start on boot, and auto-restart on failure.
-   **UFW Firewall Configuration:** Installs and configures UFW to allow only the essential ports for Monerod (18080), P2Pool (37889), and optionally the stratum port (3333).

## Prerequisites

-   **OS:** A clean installation of Debian or Ubuntu.
-   **Memory:** Minimum 2GB of RAM.
-   **Disk Space:**
    -   **100GB** if running a pruned node.
    -   **300+GB** if running a full node.

## Installation

1.  **Clone this Repository:**
    
    ```bash
    git clone https://github.com/lupettohf/monero-p2pool-installer.git
    cd monero-p2pool-installer
    
    ```
    
2.  **Review the Script:**  
    Ensure you understand the changes the script will make (it installs packages, creates system users, and sets up services).
    
3.  **Run the Installer:**  
    Run the script with root privileges:
    
    ```bash
    sudo bash install_monero_p2pool.sh
    
    ```
    
    Follow the on-screen prompts to:
    
    -   Enter your Monero wallet address.
    -   Choose between a pruned or full blockchain.
    -   Decide whether to expose the P2Pool stratum port to the internet (if you have miners outside you LAN).
4.  **Monitor the Services:**
    
    -   Check the status of monerod:
        
        ```bash
        systemctl status monerod
        
        ```
        
    -   Check the status of p2pool:
        
        ```bash
        systemctl status p2pool
        
        ```
        
    -   Use the alias `monero-status` to quickly check the Monero node sync progress (log out and back in, or source the alias file).

## Troubleshooting

-   Ensure your system meets the minimum RAM and disk space requirements.
-   For compilation errors, verify that all dependencies were correctly installed.
-   Check system logs (using `journalctl -xe` or looking at the log files in `/var/log/monero` and `/var/lib/p2pool`) for detailed error messages.

## Donations

If you find this script useful, feel free to buy me a beer!  
**XMR:** `44jvFTtPKt2PzsCXF2DgDDYxHtSGAtfkoZH3FDhiTBMvaxjoXtLVDCD1ZEmETqPxaoezBRcXbuvvAYnxUEp1WhikVmBi4eR`

## License

This project is licensed under the MIT License. See the LICENSE file for details.

----------

