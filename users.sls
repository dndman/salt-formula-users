users:
  user1:
    fullname: New User One
    uid: 5000
    gid: 5000
    shell: /bin/bash
    home: /home/user1
    groups:
      - wheel
      - admin
    password: user1
    enforce_password: True
    key.pub: True


  user2:
    fullname: New User Two
    uid: 5001
    gid: 5001
    shell: /bin/bash
    home: /home/user2
    groups:
      - wheel
      - admin
    password: user2
    enforce_password: True
    key.pub: True
