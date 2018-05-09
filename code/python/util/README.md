# Problem:

1) UpGuard node scans must be 3 levels deep to work with the storage and display of scan results
2) Sometimes custom scripts run from scan.d product JSON structures that are not 3 levels
   and contain arrays/lists of maps/dicts at certain levels that don't load well with the
   node scan viewer

# Solution:
 This script takes any json object and converts it to a proper 3 levels deep structure
 that secure is expecting and that the agents subscribe to.

# To use:

Ensure that the `pathlib2` module is installed: `pip install -r requirements.txt` 

`convert_scan` is the function that does all the work

`example_of_how_to_run` shows how you can read a file and output a fixed json format.

but you could also just import this script and call `convert_scan` on a given structure.

# Bugs/Author

Ask steve.cossell@upguard.com
