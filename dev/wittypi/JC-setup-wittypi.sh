# get the software:
sudo mkdir /opt/git/wittypiamon
sudo chown -R amon.amon /opt/git/wittypiamon

git -C /opt/git/wittypiamon clone jdmc2@shub:git/amon 

# is this the only thing we need to do?
apt-get install -y wiringpi


# previously I'd worried about "modules?".
echo "i2c-dev" >> /etc/modules

# otherwise we get:
# amon@solo:/opt/git/wittypiamon/amon/dev/wittypi $ sudo ./wp.sh status
# >>> Your system time is: Mon 30 Jul 2018 07:05:57 BST
# >>> Your RTC time is:    Mon 30 Jul 2018 07:05:58 BST
# Error: Could not open file `/dev/i2c-1' or `/dev/i2c/1': No such file or directory
# Error: Could not open file `/dev/i2c-1' or `/dev/i2c/1': No such file or directory
# Error: Could not open file `/dev/i2c-1' or `/dev/i2c/1': No such file or directory
