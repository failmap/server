# Operations
This project uses containers (Docker) for management/isolation of most of its components. By maintaining state outside of these components reliability and managability is greatly improved.

Required administrative operations can be performed using utility commands. All these commands require sudo/root.

Updating to the latest release of WebSecMap:

    sudo websecmap-deploy

Rolling back to version prior to deploy:

    sudo websecmap-rollback

Clearing cache:

    sudo websecmap-frontend-clear-cache

.... TODO
