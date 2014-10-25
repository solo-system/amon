on a raspi, you do 

# git clone jdmc2@jdmc2.com:git/amon

and it copies down the repo.  Then make a change on the raspi, git
add, git commit, and now send the change up to the central repo on
jdmc2.com

BUT before doing that - ensure nothing has change on origing:

git pull (which will do a merge if it needs to)

git push  (to push your changes up to origin)
#NOTE that git push doesn't work if the currently checked-out branch on origin is master (the one you are pushing to), since that would mean changing files under that user's feet.

so to avoid this, login to origin and type git checkout blah (where
blah is any other branch than master), you can list all local branches
with "git branch" (git branch junk creates a new branch called junk)



-----
it seems that git pull on raspberry pi not only brings down the changes from origin (jdmc2.com), but also any new branches.  I think that's ok...

All this would probably be better If I used branches, but NOT for the moment - stick to one for the moment.

J.
