Symfony Standard Edition + Deployment Pipeline (Beta)
====================================================

This is a fork of
https://github.com/symfony/symfony-standard

In addition it prepares your symfony app to be deployed in a nice deployment pipeline - following our best practice.
In details this fork adds the following features:

  * Added the doctrine Migrations Bundle

  * Added ant build scripts for building an installable package of your symfony application

  * Includes a best practice setup script

  * Suggested a deployment script: https://github.com/danielpoe/symfony-easydeployworkflow

1) The Deployment Pipeline
----------------------------
A deployment pipeline makes sure, that your latest changes can be tested and deployed in an automated and reproduceable way.
Our symfony deployment-pipeline works like this:

1. BUILD:	A "commit" or "build" job makes sure, that the latest codebase (and everything else required for installing your application) is packaged in a .tar.gz file.
  This is called "build-artifact".

2. DEPLOY ON LATEST: Next you need to deploy the created package to a real system.
	Because you want to know if the package can be installed of course. See below to read more details about the Deployment automation.

3. Acceptance Tests: Once the package is installed, you want to call an URL and see if your application still works like it should.
	Use something like cucumber or selenium for this..

4. DEPLOY ON STAGING / PRODUCTION: At the end you want to install the application on staging and later on production.
	You are doing it the same way like you did it for "DEPLOY ON LATEST". The only difference might be that you now deploy to a cluster instead of a single node.


2) The Build Step
-------------------------

### Build targets

The build is responsible for:

 *	getting latest code
 *	do composer install (based on the composer.lock)
 *	Optional: Run Unit Tests
 *	Optional: Compress CSS and JS for your application
 *	Creating a version file (that identifies the version of your packaged application)
 *	Creating the tar.gz file - ready to be downloaded by your deployment Script

The created package can now be downloaded and installed to any environment. Of course your application needs informations from the
infrastructure: Like database, folder locations, context etc...  The simple idea is, that the installation process will ask the environment for that informations.
We are using environment variables for this.

To build a package just checkout the code and call the included ant file:
::

	cd build
	ant -Dversion=1

This will then download composer and build a package.
If you want to use your global composer installation instead of downloading composer you can specify the path:
::

	ant -Dversion=1 -Dcomposerpath=/path/to/composer.phar buildpackage


The package will be automatically stored in ../artifacts/symfony2app.tar.gz
You can override this with the following properties:
::

	artifactdir
	projectname

### Usage in Jenkins:

Simple set this suggested properties:
::

	artifactdir=${WORKSPACE}/../builds/${BUILD_NUMBER}/archive/
	version = ${BUILD_NUMBER}
	projectname = experiencemanager

### "composer update" target

You can also run the included "updateComposerLock" target to update your composer.lock file - including commit to your repository.

3) Deployment and Setup
-----------------------

The goal of the deployment is, to have a certain version of the package running on an environment.
The environment can be either one server or a cluster with multiple nodes.

Following best practice (you may have read about the Twelve-Factor App) our goal is, that the package can be installed to any environment.
Of course the application in the package has dependencies to the infrastructure - like a database connection etc.
This kind of dependency should be "injected" to the deployment process: You can think of it like if the applications asks for "Hey infrastructure - which database should I use?"

### General Termdefinition and Thoughts

---------------------------------------

_environment:_ definition of the infrastructure that is involved in the deployment.
			For example there might be an environment "dev-local" that defines that only the localhost is used in the deployment.
			Or there might be an environment "production-cluster" that defines that we have 4 servers where the application should be deployed.

---------------------------------------

_application-context:_ Symfony also uses the term "environment" to be able to run the application in different contexts (with different cache and other configurations).
			There should be a limited amount of contexts - in most cases "dev", "test", and "production" should be sufficent.
			An application can run in "test" context on the "production-cluster" environment.

---------------------------------------

_setup:_	The steps required to install a specific version of your application. The setup steps are highly coupled to the packaged application and not to the infrastructure.
 		Typically for a symfony application this includes steps for adjusting the configuration to use the correct database, run the database migration (migrate up), install assets, clean caches etc..
 		The setup needs to know the "application-context" and it should ask the infrastructure for the required resources (like database)

---------------------------------------

_deployment:_ The process of bringing a new version of an application on a new or existing infrastructure. It may involves provisioning and preparing steps on the infrastructure, creating backups, show intermediate maintenance pages, downloading the desired version of the application,
			updating loadbalancers, warming up caches etc...

The deployment follows a certain workflow, that orchestrates the steps required for having the application running on the target environment.
The workflow may depend on the environment.

---------------------------------------

### Manual Installation and Setup

Ok lets say you have your package "symfony2app.tar.gz" build as the result of the build step above.
Now you can install it in a directory of your choice:
::

	wget <your artifact location>/symfony2app.tar.gz
	tar -xzf symfony2app.tar.gz
	./symfony2app/setup.sh

You will notice that the setup.sh script fails with a message that it misses informations about the application context, the database etc..
So we pass this infrastructure dependencies via environment variables:

	export ENVIRONMENT="local" && export CONTEXT="dev" &&   export WEBGROUP="www-data" && export WEBUSER="www-data" && export DBHOST="localhost" && export DBNAME="spm_qvc" && export DBUSER="root" && export DBPASSWORD="root" && export SECRET="lkajsdlaksdj"  ./symfony2app/setup.sh


### Details about the configuration adjustment

The setup script is able to adjust any configuration in any file or database table. This is done with the "EnvSettingsTool": https://github.com/AOEpeople/EnvSettingsTool
The initial CSV file with the settings can be found in setup/env-settings.csv. It is configured to adjust the parameter.yml file with the correct database settings.


### Suggested Deployment Script

Ok - you normally don't want to trigger the setup manually. So you probably want to create a short deployment script that will do it for you.

We have one prepared as a kickstart: Its a PHP based deployment script build with Easydeployworkflows
You can find the deployment script here: https://github.com/danielpoe/symfony-easydeployworkflow

Mainly the tasks of that deployment is:

 * Download the correct package that should be installed from a source. (E.g. your Jenkins artifacts) The download is stored in an intermediate "deliveryfolder"
 * Extract the folder to the release folder - in a subdirectory with the correct versionnumber
 * Update the "next" Symlink to point to the new release
 * Run the Setup of the application
 * Run Smoke Test
 * Switch: Update "current" and "previous" symlinks
 * Cleanup old releases


4) Next Steps
----------------------------

After you have cloned this repository you can add your symfony application like described in the original README: https://github.com/symfony/symfony-standard

Basically for a project kickstart this should be the steps:

::

 # Clone this kickstart repository somewhere on your development server
 git clone https://github.com/danielpoe/symfony-standard.git myproject-kickstart

 # Do first local build
 cd myproject-kickstart/build
 ant -Dversion=1

 # smoketest
 cd ..
 php app/check.php

 # Kickstart your project Bundle
 php app/console generate:bundle

 # check in everything to a new repository
 git remote add myname yourrepositoryurl
 gut pull
 git add src/yourvendorname
 git push myname master


Then you have a new symfony project repository kickstarted, and you can setup the deployment pipeline for this:

 * Create a build job like explained above
 * Prepare the system (vHost, Database etc) and create a install job like explained above:
 ::

  git clone https://github.com/danielpoe/symfony-easydeployworkflow
  # do your adjustments on the deployment script (artifact location etc...)
  # check in everything to a new deployment repository
  # use this deployment script to deploy to your environment

...

### Other hints:

 * Uncomment the "migrate up" call in setup.sh as soon as you have your first database migration file in the package
