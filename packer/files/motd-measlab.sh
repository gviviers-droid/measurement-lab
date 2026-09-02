#!/bin/bash
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
cat << BANNER

=================================================================
       Welcome to the Internet Measurements Lab Appliance
=================================================================
  * Control Portal & Activities: http://localhost:8080
  * VM Direct IP:                http://${IP:-<vm-ip>}:8080
  * Default user / password:     learner / measlab
  * Lab directory:               /home/learner/measurement-lab
=================================================================

BANNER
