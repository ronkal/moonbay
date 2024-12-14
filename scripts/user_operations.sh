#!/usr/bin/env -S bash -e

# Setting up a password for the user account.
user_creation() {
    while true; do
        input_print "Please enter a name for your user account (leave empty to not create one): "
        read -r username
        if [[ -z "$username" ]]; then
            return 0
        fi
        input_print "Please enter a password for $username (you're not going to see the password): "
        read -r -s userpass
        if [[ -z "$userpass" ]]; then
            echo
            error_print "You need to enter a password for $username, please try again."
            continue
        fi
        echo
        input_print "Please enter the password again (you're not going to see it): "
        read -r -s userpass2
        echo
        if [[ "$userpass" != "$userpass2" ]]; then
            echo
            error_print "Passwords don't match, please try again."
        else
            break
        fi
    done
    return 0
}

# Setting up a password for the root account.
root_user_creation() {
    while true; do
        input_print "Please enter a password for the root user (you're not going to see it): "
        read -r -s rootpass
        if [[ -z "$rootpass" ]]; then
            echo
            error_print "You need to enter a password for the root user, please try again."
            continue
        fi
        echo
        input_print "Please, repeat the password for confirmation (you're not going to see it): "
        read -r -s rootpass2
        echo
        if [[ "$rootpass" != "$rootpass2" ]]; then
            error_print "Passwords don't match, please try again."
        else
            break
        fi
    done
    return 0
}