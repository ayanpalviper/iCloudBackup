# iCloudBackup

This little hack is to 'ease' the process of backing up all photos from the iCloud Photos folder in your windows machine

Apple is literally terrible with their windows software and they do not let you choose the directory in which the photos should be backed up. ar actually any useful feature at all

So this repository will allow you to run powershell scripts in the background to regularly update the photos to an external drive when the drive is connected and the internet connection is present

Also note that there is a difference to how the iCloud app on windows behnaves in comparison to the iCloud natively on iOS or any apple divice. The Photos in accross all you apple divices can be unified to behnave like one application accross all your Apple device if you so choose. So if you delete one photo from a device it will delete the photo from iCloud and all devices synched to that account

BUT in windows, Apple (thankfully to our advantage) has supressed this feature. So all photos will be available to the iCloud Photos sync folder on your windows PC and if you delete a photo from the direcotry then it wont be re-downloaded (unless you go to the windows iCloud App and resync all photos). ALSO if you delete a photo from this directory then unlike in iOS the photo WILL NOT be deleted from iCloud

So i have basically taken advantage of this feature and timely backed up all photos to an external drive

The file differences can be maintained by name or by creating database of all file and their corresponding hashes (Fancy i know!!)
You can manage with comparing file names so that you dont end up copying duplicate files every time your iCloud Photos sync folder is reset. But this is a more methodical approach you can say.

Please note that its best to put this script on a scheduler like once a day or something like that and also turn on the 'Always keep on device' feature for the sync folder once you have intially dumped all the files to your external backup.
This will prevent the script from timing out everytime iCloud tries to sync a large video file (like a 5GB 4K clip).

If you have the 'Always keep on device' feature on then you can just ignore the files that have a disk size of 0 (this means that the file is not yet downloaded to the local directory)

I had fun coding this tiny tiny project and i hope this ends up being useful to whoever plans to use this

Cheers!!
