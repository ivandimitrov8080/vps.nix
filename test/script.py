start_all()

vpsfree_ip = "192.168.1.5"

spoke.wait_until_succeeds("ping -c1 vpsfree")
spoke.wait_until_succeeds("ip a show wg0 | rg UP")
vpsfree.wait_until_succeeds("ip a show wg0 | rg UP")
print(vpsfree.succeed("ip a"))
vpsfree.succeed(f"ip a | rg {vpsfree_ip}")

vpsfree.succeed("ping -c1 10.0.0.2")
spoke.succeed("ping -c1 10.0.0.1")

print(outsider.succeed("curl service"))
print(spoke.succeed(f"curl service | rg {vpsfree_ip}"))

print(vpsfree.succeed("ls -al /run/secrets"))
print(vpsfree.succeed("ls -al /run/secrets-for-users"))

vpsfree.wait_for_unit("nginx.service")

vpsfree.wait_for_unit("matrix-synapse.service")
