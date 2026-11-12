import os
from pathlib import Path
from test_driver.driver import Driver, load_driver_configuration
from test_driver.logger import CompositeLogger, TerminalLogger

cfg = load_driver_configuration(os.environ["NIXOS_TEST_DRIVER_CONFIG"])

with Driver(cfg, Path.cwd(), CompositeLogger([TerminalLogger()])) as d:
    d.start_all()
    globals().update(d.test_symbols())
    vpsfree  = next(m for m in d.machines_nspawn if m.name == "vpsfree")


