# Drafts App and exporting text files
Getting documents out of the Drafts App (iOS, iPadOS, macOS) - for use in iA Writer, for example

The "Drafts" App for macOS, iPadOS and iOS is just a fantastic tool to create, handle and publish text files.

There is just one problem:

If you don't pay for a subscription, you can run into problems to get your texts out of the App again.
This is because Drafts does not create text files, but instead handles all texts in an internal database.

If you want to get your texts out of this "hostage" situation, you can only export as one giant text file with any and all of you texts, or export as JSON or CSV file.
But none of those options provide you with a folder that contains separate text files.

And any better export option requires you to subscribe first. This is a sad situation.

For this, I created this bash script:

It requires the installation of "jq" and "miller" - for which is checks and outputs some option to install them - an empty folder and a JSON export file from the Drafts App.

You can use it like this:

$ mkdir DRAFTS
$ cd DRAFTS
$ ~/bin/drafts.sh ~/drafts_export.json

You will find 3 new sub-folder: DRAFTS, LINKS and DOCS.

DRAFTS contians the orignal exported versions, named after the UUID of the texts from the Drafts database.
LINKS contains hard links that have instead an extract of the first line from each file as their name.
And finally DOCS, which contain the final text files, sorted in directories for each year and having tags and flagged status added as metadata in the header of each file and the different timestamps set as the originals.

The script is not very elegant, but did fulfill my needs.
Feel free to contribute.

-tja
