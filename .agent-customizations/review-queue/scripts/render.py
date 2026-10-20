"""Write the static review queue page. Usage: python3 -I render.py [--out FILE]

The static page can filter and sort, but its review buttons only copy a command. Run
serve.py to get working review buttons.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from queue_lib import PAGE_FILE, load_data, render_page  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=PAGE_FILE)
args = ap.parse_args()
data = load_data()
open(args.out, "w").write(render_page(data))
print("wrote", args.out, len(data["mrs"]), "MRs")
