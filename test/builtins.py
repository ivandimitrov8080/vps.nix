import os
from test_driver.driver import load_driver_configuration, pythonize_name

cfg = load_driver_configuration(os.environ["NIXOS_TEST_DRIVER_CONFIG"])
names = sorted({pythonize_name(n) for n in (*cfg.vms, *cfg.containers)})
qemu_machines = sorted({pythonize_name(n) for n in cfg.vms})
nspawn_machines = sorted({pythonize_name(n) for n in cfg.containers})

body = f"""
from test_driver.machine import BaseMachine, NspawnMachine, QemuMachine

{'\n'.join(f'{q}: QemuMachine' for q in qemu_machines)}

{'\n'.join(f'{n}: NspawnMachine' for n in nspawn_machines)}

"""
print(body)
