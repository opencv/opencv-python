from os.path import join, dirname, abspath
import json

from auditwheel import policy


def add_zlib_versions():
    with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json"), 'r') as manylinux_policy:
        manylinux_policy_lines = manylinux_policy.readlines()

    manylinux_policy_data = ""
    for line in manylinux_policy_lines:
        if "ZLIB" in line:
            if len(line) > 22:
                updated_line = line[:-2] + ', "1.2.9", "1.2.12"]'
            else:
                updated_line = line[:-2] + '"1.2.9", "1.2.12"]'
            print("auditwheel patch: replace policy line \"%s\" with \"%s\"" % (line, updated_line))
            manylinux_policy_replacement = line.replace(line, updated_line)
        else:
            manylinux_policy_replacement = line
        manylinux_policy_data = manylinux_policy_data + manylinux_policy_replacement

    with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json"), 'w') as manylinux_final_policy:
        manylinux_final_policy.write(manylinux_policy_data)

def add_whitelisted_libs():
    policies = None

    with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json")) as f:
        policies = json.load(f)

    for p in policies:
        p["lib_whitelist"].append("libxcb.so.1")

    with open(join(dirname(abspath(policy.__file__)), "manylinux-policy.json"), "w") as f:
        f.write(json.dumps(policies))


if __name__ == '__main__':
    add_zlib_versions()
    add_whitelisted_libs()
