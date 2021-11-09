from os.path import join, dirname, abspath
import json

from auditwheel import policy

policies = None

with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json")) as f:
    policies = json.load(f)

for p in policies:
    p["lib_whitelist"].append("libxcb.so.1")

with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json"), "w") as f:
    f.write(json.dumps(policies))
