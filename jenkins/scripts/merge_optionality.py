from sys import argv

import yaml


# PRIVATE FUNCTIONS

def __merge_optionality(optionality_yaml, data):
    if type(optionality_yaml) is not dict or type(data) is not dict:
        print('ERROR: argument is not a valid python dictionary:')
        print('type(optionality_yaml)={}    type(data)={}'
                .format(str(type(optionality_yaml)), str(type(data))))
        exit(-2)

    for k in data:
        if k not in optionality_yaml:
            optionality_yaml[k] = data[k]
        elif type(optionality_yaml[k]) is dict and type(data[k]) is dict:
            __merge_optionality(optionality_yaml[k],data[k])
        elif type(optionality_yaml[k]) is bool and type(data[k]) is bool:
            if data[k] == True:
                optionality_yaml[k] = True
        else:
            print('ERROR: key already in optionality_yaml but with different type')
            print('type(optionality_yaml[k])={}    type(data[k])={}'
                    .format(str(type(optionality_yaml[k])), str(type(data[k]))))
            exit(-3)



# MAIN
def usage(argv):
    print(
    """
    Create a file called optionality.yaml merging multiple optionality.yaml from
    different helm charts. The output contains all the content of the file that this
    script will merge keeping the value 'true' in case tha same key has different
    values.

    Usage:
        {} <payh_to_first_optionality.yaml> [<payh_to_second_optionality.yaml> ...]
    Note:
        at least one files need to be given.
    """.format(argv[0]))

def main():
    if len(argv) < 2:
        usage(argv)
        exit(-1)

    optionality_yaml = dict()
    for i in range(1,len(argv)):
        with open(argv[i]) as f:
            data = yaml.safe_load(f)
        __merge_optionality(optionality_yaml, data)

    with open('optionality.yaml', 'w') as f:
        yaml.safe_dump(optionality_yaml, f, default_flow_style=False)


if __name__ == '__main__':
    main()


