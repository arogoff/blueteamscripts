# Blue Team Scripts

## change_passwords.sh

This script goes through the provided users list and generates new passwords. Passwords are then displayed from a tmp file so you can grab them, then it is promptly deleted from memory.

## find_flags.sh

This script goes through the entire file system, omitting certain directories, to search for flags. Flags are in the syntax of `FLAG{*}`, and file contents as well as file names are searched for. Flags are then displayed from a tmp file so you can grab them alogn with their path, then it is promptly deleted from memory.

## change_mysql_passwords.sh

This script goes through the provided users list and generates new passwords for MySQL access. Passwords are then displayed from a tmp file so you can grab them, then it is promptly deleted from memory.
Changes for 'localhost' access.

## change_smb_passwords.sh

This script goes through the provided users list and generates new passwords for SMB access. Passwords are then displayed from a tmp file so you can grab them, then it is promptly deleted from memory.
