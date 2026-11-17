from test_driver.machine import BaseMachine


start_all()

vpsfree_ip = "192.168.1.5"

def wait_for_service(machine: BaseMachine, service: str):
    machine.wait_for_unit(f"{service}.service")

def vpsfree_service_test():
    services = ["matrix-synapse",
                "mautrix-telegram",
                "livekit",
                "dnscrypt-proxy",
                "nginx"
                ]
    for s in services:
        wait_for_service(vpsfree, s)

def wireguard_test():
    spoke.succeed("ip a show wg0 | rg UP")
    vpsfree.succeed("ip a show wg0 | rg UP")
    vpsfree.succeed("ping -c1 10.0.0.2")
    spoke.succeed("ping -c1 10.0.0.1")
    outsider.succeed("curl service")
    spoke.succeed(f"curl service | rg {vpsfree_ip}")


def sops_test():
    vpsfree.succeed("ls -al /run/secrets")
    vpsfree.succeed("ls -al /run/secrets-for-users")


# Order the test execution
sops_test()
wireguard_test()
vpsfree_service_test()
