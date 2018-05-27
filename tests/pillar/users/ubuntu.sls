users:
  canonical:
    fullname: ubuntu user
    uid: 5000
    gid: 5000
    shell: /bin/bash
    home: /home/canonical
    groups:
      - sudo
    password: $6$SALTsalt$UiZikbV3VeeBPsg8./Q5DAfq9aj7CVZMDU6ffBiBLgUEpxv7LMXKbcZ9JSZnYDrZQftdG319XkbLVMvWcF/Vr/
    enforce_password: True
    key.pub: True
    publickey: 
       - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDaa8vHkKwqlkc08HL8xzAdP9+bJH6cW7jXPrAxPHExO1rIIF7kXsEV9IffjhZ4KXTCPU5Dmsfeyy51f2wQC40nKRqQOqwnyHN6nowmHPDtECYPOuIjOYM3RFGX5s09zfeYvaxWon9MCP9mniYK8rHU4AEkhmOiIxBMoemj/vhP4ocgZocHcC5hKBesrSgz6wLc/lCNOuKsOG40rupvAECxLNOF+tQxma934tuGe9gk+DLPeulze+3zTQw3KkMuBhlCv85twX0dV//7Bab23rQYi1FtaqMzyKv1pwIqi8tWfw9hFkb5BxprenGVggpIP8l6Myuj8qhkZ076Tr2ZObDh root@saltplate-ubuntu

  redhat:
    removeuser: kill


