import os
import paramiko
import getpass

# List of remote servers
REMOTE_SERVERS = [
    {"host": "13.93.235.17", "user": "azureuser"},
    {"host": "40.85.159.145", "user": "azureuser"},
    {"host": "40.85.158.251", "user": "azureuser"},
    # Add more servers as needed
]

# Path to SSH key
SSH_KEY_PATH = os.path.expanduser("~/.ssh/id_rsa.pub")


# Function to generate SSH key pair if not exists
def generate_ssh_key():
    if not os.path.exists(SSH_KEY_PATH):
        print("Generating SSH key...")
        os.system("ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ''")
    else:
        print("SSH key already exists.")


# Function to copy SSH key to remote server
def copy_ssh_key(host, user, password):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(host, username=user, password=password)
        sftp = ssh.open_sftp()
        sftp.mkdir(".ssh", ignore_existing=True)
        sftp.put(SSH_KEY_PATH, ".ssh/authorized_keys")
        sftp.close()
        ssh.exec_command("chmod 700 ~/.ssh")
        ssh.exec_command("chmod 600 ~/.ssh/authorized_keys")
        print(f"SSH key added to {host}")
    except Exception as e:
        print(f"Failed to copy SSH key to {host}: {e}")
    finally:
        ssh.close()


# Function to verify SSH connection
def verify_connection(host, user):
    response = os.system(f"ssh -o BatchMode=yes -o ConnectTimeout=5 {user}@{host} echo success")
    if response == 0:
        print(f"Successfully connected to {host} using SSH key.")
    else:
        print(f"Failed to connect to {host} using SSH key.")


if __name__ == "__main__":
    generate_ssh_key()

    for server in REMOTE_SERVERS:
        password = getpass.getpass(prompt=f"Enter password for {server['user']}@{server['host']}: ")
        copy_ssh_key(server["host"], server["user"], password)
        verify_connection(server["host"], server["user"])
