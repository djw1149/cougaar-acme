echo "<society>"
egrep "((host|node|agent) name|/host|/node|/agent)" "$1"
echo "</society>"
