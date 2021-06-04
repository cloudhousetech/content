
# Problem:
# 1) UpGuard node scans must be 3 levels deep to work with the storage and display of scan results
# 2) Sometimes custom scripts run from scan.d product JSON structures that are not 3 levels
#    and contain arrays/lists of maps/dicts at certain levels that don't load well with the
#    node scan viewer
# Solution:
# This script takes any json object and converts it to a proper 3 levels deep structure
# that secure is expecting and that the agents subscribe to.

from pathlib2 import Path
import json

def is_dict(o):
    return isinstance(o, dict)

def is_list(o):
    return isinstance(o, list)

def is_string(o):
    return isinstance(o, basestring)

def is_bool(o):
    return isinstance(o, bool)

def is_int(o):
    return isinstance(o, int)

def is_float(o):
    return isinstance(o, float)

def is_value(o):
    return is_string(o) or is_bool(o) or is_int(o) or is_float(o)

# given a dict of key value pairs, tires to find an appropriate key name to an element
#  in the dict that would make a good "name" for that dict, so that it can be put into the
#  node scan structure as something like:
#  { "name_of_object": { ... object ... } }
def find_good_name(o):
    # TODO : add more keys to search for if you want more that just "name" to be the name of something
    if "name" in o:
        return "name"
    elif "Name" in o:
        return "Name"
    elif "id" in o:
        return "id"
    elif "VpcId" in o:
        return "VpcId"
    elif "Key" in o and "Value" in o:
        return "Value"
    elif "path" in o:
        return "path"
    elif "counterSpecifier" in o:
        return "counterSpecifier"
    elif len(o) == 1:
        return o.keys()[0]
    else:
        print "find for me a nice value in these values I can use as a name"
        print o.keys()
        raise "Not Implemented"


# tries to expand out arrays into dictionaries
def compact(scan):
    ret = {}

    if is_dict(scan):
        # good
        for key in scan:
            val = scan[key]
            if is_string(val):
                ret[key] = val
            else:
                ret[key] = compact(val)

    elif is_list(scan):
        # need to turn this into a dict
        for elem in scan:
            if is_dict(elem):
                name_key = find_good_name(elem)
                name = elem[name_key]
                if is_dict(name):
                    ret[name_key] = compact(elem)
                else:
                    ret[name] = compact(elem)
            else:
                raise "don't know how to translate a list of non-dicts yet, please teach me"
    elif is_value(scan):
        return scan
    else:
        print "Not Implemented"
        print "scan:"
        print scan
        raise "Not Implemented"

    return ret

# takes in a dict<string, dict<string, ....>> and tries to make it just a dict<string, string>
def flatten(obj):
    while is_flat(obj) == False:
        obj = flatten_1_layer(obj)
    return obj

def is_flat(obj):
    if is_value(obj):
        return True
    elif is_dict(obj):
        all_vals_are_strings = True
        for key in obj:
            val = obj[key]
            if is_string(val) == False:
                all_vals_are_strings = False
        return all_vals_are_strings
    else:
        print "don't know how to is_flat this type"
        print type(obj)
        raise "Not Implemented"


def flatten_1_layer(obj):
    if is_string(obj):
        return obj
    elif is_dict(obj):
        ret = {}
        for key in obj:
            val = obj[key]
            if is_string(val):
                ret[key] = val
            elif is_dict(val):
                for k1 in val:
                    v1 = val[k1]
                    new_key = key + " " + k1
                    ret[new_key] = flatten(v1)
        return ret
    else:
        raise "Not Implemented"

# assumes we only have 'dict's and 'string's and any lists/arrays have been compacted out from the 'compact' function
def make_3_deep(scan):
    for k1 in scan.keys():
        v1 = scan[k1]
        if is_value(v1):
            scan[k1] = {"value":{"value": {"value": v1}}}
            continue
        elif is_dict(v1) == False:
            raise "Not Supported"

        for k2 in v1.keys():
            v2 = v1[k2]
            if is_value(v2):
                v1[k2] = {"value":{"value": v2}}
                continue
            elif is_dict(v2) == False:
                raise "Not Supported"

            for k3 in v2.keys():
                v3 = v2[k3]
                if is_value(v3):
                    v2[k3] = {"value": v3}
                    continue
                elif is_dict(v3) == False:
                    raise "Not Supported"

                all_of_v4s_are_values = True
                for k4 in v3.keys():
                    v4 = v3[k4]
                    if is_value(v4):
                        continue
                    else:
                        all_of_v4s_are_values = False
                if all_of_v4s_are_values == False:
                    v2[k3] = flatten(v3)
    return scan

# function to help test the make_3_deep function
def validate_proper_node_scan_struct_depth(scan):
    if is_dict(scan) == False:
        print "FAIL: not a dict at level 1"
        print scan
        return False
    for k1 in scan:
        v1 = scan[k1]
        if is_dict(v1) == False:
            print "FAIL: not a dict at level 2"
            print k1 + " > " + str(v1)
            return False
        for k2 in v1:
            v2 = v1[k2]
            if is_dict(v2) == False:
                print "FAIL: not a dict at level 3"
                print k1 + " > " + k2 + " > " + str(v2)
                return False
            for k3 in v2:
                v3 = v2[k3]
                if is_dict(v3) == False:
                    print "FAIL: not a dict at level 4"
                    print k1 + " > " + k2 + " > " + k3 + " > " + str(v3)
                    return False
                for k4 in v3:
                    v4 = v3[k4]
                    if is_string(k4) == False:
                        print "FAIL: level 4 key isn't a string"
                        print k4
                        return False
                    if is_value(v4) == False:
                        print "FAIL: level 4 value isn't a recognised value"
                        print v4
                        return False
    return True

# the main function to call to convert a scan to nice format
def convert_scan(scan):
    compacted = compact(scan)
    return make_3_deep(compacted)

def example_of_how_to_run():
    # load up the JSON content into a proper python structure
    #  (you could also just import this file and send the structure to `convert_scan` directly
    filename = "input.json"
    content = Path(filename).read_text()
    obj = json.loads(content)
    fixed = convert_scan(obj)
    output_json = json.dumps(fixed)
    print output_json

# example_of_how_to_run()

# ----------------------------------------
# sandbox area for quick unit testing of functions
def assertEqual(expected, actual):
    if expected == actual:
        print "PASS"
    else:
        print "FAIL"
        print "  Expected:"
        print expected
        print "    Actual:"
        print actual

# test flatten
def runTests():
    assertEqual(
        {"a b": "banana", "a c": "carrot"},
        flatten({"a":{"b":"banana", "c":"carrot"}})
    )
    assertEqual(
        {"a b c": "carrot", "a b d": "dog"},
        flatten({"a":{"b":{"c":"carrot", "d":"dog"}}})
    )
    assertEqual(
        {"a b c d": "dog", "a b c e": "egg"},
        flatten({"a":{"b":{"c":{"d":"dog","e":"egg"}}}})
    )

    proper_input = {"env vars": {"linux": {"PATH": {"name":"PATH", "value": "/bin" } } } }
    output = convert_scan(proper_input)
    assertEqual(
        True,
        validate_proper_node_scan_struct_depth(output)
    )

    input_with_arrays = {"subnets": [{"name":"north", "range":"192.168.1.1"}, {"name": "south", "range": "1.1.1.1"}]}
    output = convert_scan(input_with_arrays)
    assertEqual(
        True,
        validate_proper_node_scan_struct_depth(output)
    )

    input_with_arrays_in_arrays = {"subnets": [{"name":"north", "range":"192.168.1.1", "tags": [{"name":"resident", "value":"santa"}]}, {"name": "south", "range": "1.1.1.1", "tags":[{"name":"resident", "value": "penguin"}]}]}
    output = convert_scan(input_with_arrays_in_arrays)
    assertEqual(
        True,
        validate_proper_node_scan_struct_depth(output)
    )


# runTests()
