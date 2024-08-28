
import yaml

# PRIVATE FUNCTIONS

def _merge_lists(base_lst, override_lst):
    return override_lst

def _merge_dict(base, override):
    for k in override:
        #print (f'k={k}')
        if k == 'tags':
            base[k] = override[k]
        elif type(override[k]) not in [dict, list] \
                or k not in base             \
                or type(base[k]) != type(override[k]) :
            base[k] = override[k]
        elif type(override[k]) is list:
            base[k] = _merge_lists(base[k], override[k])
        else:
            base[k] = _merge_dict(base[k], override[k])
    return base

# PUBLIC FUNCTIONS

def merge_data(base, override):
    """Return a dictionary or a list with the same content of 'base' overrided
    by the content of 'override'. In other words this function copy 'base' and update
    its contents: what is in 'override' that is not in 'base' will be added and if the
    same key in 'override' has a different value in 'base' then the value from 'override'
    will be taken."""

    if type(override) is not type(base):
        return None, "'base.yaml' and 'override.yaml' have different structure"

    if type(override) is list:
        return _merge_lists(base,override), None

    return _merge_dict(dict(base),dict(override)), None

def merge_yaml(base_yaml, override_yaml):
    """Merge two files and return the resulting dictionary or list.
    See merge_data() for details about the merge strategy."""

    with open(base_yaml) as f:
       base = yaml.safe_load(f)

    with open(override_yaml) as f:
       override = yaml.safe_load(f)

    if override is None or override == '':
        return base, None
    else:
        return merge_data(base, override)


# MAIN
def usage(argv):
    print(
    """
    Usage:
        {} <base.yaml> <override.yaml> <output.yaml>
    """.format(argv[0]))

def main():
    from sys import argv
    if len(argv) != 4:
        usage(argv)
        exit(-1)

    data_merged, err = merge_yaml(argv[1], argv[2])
    if data_merged is None:
        print('[{}] Error: {}'.format(argv[0], err))
        exit(-2)

    with open(argv[3], 'w') as f:
        yaml.safe_dump(data_merged, f, default_flow_style=False)


if __name__ == '__main__':
    main()
