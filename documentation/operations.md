# Operations
This project uses containers (Docker) for management/isolation of most of its components. By maintaining state outside of these components reliability and managability is greatly improved.

Required administrative operations can be performed using utility commands. All these commands require sudo/root.

Updating to the latest release of Failmap:

    sudo failmap-deploy

Rolling back to version prior to deploy:

    sudo failmap-rollback

Clearing cache:

    sudo failmap-frontend-clear-cache

.... TODO
