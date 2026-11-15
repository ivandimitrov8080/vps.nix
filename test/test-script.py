start_all()


spoke.wait_until_succeeds("ping -c1 vpsfree")
spoke.wait_until_succeeds("ip a show wg0 | rg UP")
vpsfree.wait_until_succeeds("ip a show wg0 | rg UP")

vpsfree.succeed("ping -c1 10.0.0.2")
spoke.succeed("ping -c1 10.0.0.1")
