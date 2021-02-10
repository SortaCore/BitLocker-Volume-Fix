# BitLocker-Volume-Fix
When "parameter is incorrect" bugs occur when opening a BitLocker drive, after unlocking the 
drive with the correct password, this script can be used to correctly mount it.

## How to run the script
Edit lines 12-15 before running!  
And run it with admin permissions.  
(If you're using scheduled tasks to do it on bootup, set up your user as login, and enable the 
"Run with highest privileges" box.)

The "interim letter" should be a letter you're not ever using; as part of the fix,
the VHDX will take this letter temporarily in the middle of the process. After unlocking,
the VHDX will have the "end letter" letter.

Also note the text files included with this script are necessary. Some more text files will be generated.

## If it doesn't work anymore
In the event this script no longer works, and you still get a "parameter is incorrect" error,
change the interim letter you're using in line 15.

You may also want to go into the registry and delete any mention of the original interim 
letter, as that usually gets things working again.

## How to do it manually
Steps the script performs for those wanting a manual Disk Management way:
1. Attach the drive.
2. Remove all drive letters it uses. No need to unlock BitLocker.
3. Detach the drive.
4. Attach the drive again. It should have no drive letters.
5. Add a different drive letter, not the one you intend to use.
6. Detach the drive again.
7. Attach the drive again.
8. Unlock the drive with its different letter, using BitLocker password input.
9. Change drive letter back to what it should be.
10. Drive is now unlocked properly.

Note that these steps will need repeating every time the computer starts up, so maybe use a scheduled task instead.  
(remember to run it as your user, and check the highest privileges box)

## Extra
This script will also have some safeguards for startup under midway points, e.g. running it while drive is already mounted, etc.  
This script will use the TXT files in the same folder. It will also generate more TXT files.
