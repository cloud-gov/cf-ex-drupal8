# cf-ex-drupal8

In-progress Drupal 8 example for Cloud Foundry

The overall aim here is to help Drupal site administrators understand how to run a production-worthy Drupal 8 site in Cloud Foundry. 

This includes:
* this is how you run this thing
* here are some of the nice attributes
* here’s how to install plugins cleanly and keep it up-to-date with new versions of Drupal 8

We'll also provide some guidance on what someone would need to do to reproduce this on their own codebase if they _don’t_ use this codebase as a starting point.

The code examples target [cloud.gov](https://cloud.gov) but should be amenable to any Cloud Foundry foundations that provide MySQL and object storage (_a la_ AWS's S3).  

The goal here is for folks who are just getting started with cloud.gov to have an eye-poppingly simple route from “I have a cloud.gov account” to “I have a production-worthy Drupal site running on a FedRAMP-authorized CSP that I understand how to update, just waiting for me to customize it”.
