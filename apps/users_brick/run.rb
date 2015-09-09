count = 1
while true do
    
x = <<-eos
if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then

  \# First try to load from a user install
  source "$HOME/.rvm/scripts/rvm"

elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then

  \# Then try to load from a root install
  source "/usr/local/rvm/scripts/rvm"

else

  printf "ERROR: An RVM installation was not found.\n"

fi;
rvm gemset use test;
yes yes | rvm gemset empty test;
gem install bundle;
bundle install;
eos
  system x
  fail if $?.exitstatus != 0
  puts count
  count += 1
end
puts count
