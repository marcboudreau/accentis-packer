accentis-packer
===

This repository contains [Packer](https://packer.io) specifications for building Google Compute Engine (GCE) Images.  These Images are used to initialize the boot disk of GCE Instances provisioned within the Accentis Google Cloud Platform (GCP) projects.

# Packer

Packer supports two formats for its template file: **JSON** and **HCL**.  The **HCL** is used in this repository because it is more readable than the **JSON** format.  The template file can produce different images, each is identified by a build name.

# Image Lifecycle

This process leverages GCE Image Families to manage the lifecycle of the images it produces.

![Lifecycle Diagram](./packer-image-lifecycle.png)

## GCE Image Families

GCE Image Families are used to group revisions of the same image project.  Referring to an image families instead of a specific images, will result in the latest non-deprecated image within that family to be used.

## Automated Process

The automated process consists of three phases:
1. Build phase
1. Verification phase
1. Promotion phase

The Build phase consists of running Packer tool to produce all of the images defined in the template.  The produced images are candidate images.  The candidate images are named: `<build_name>-candidate-<commit_hash>`.  The `<build_name>` is the name of the image as specified in the **source** block in the template file.  The `<commit_hash>` is the shorthand git commit hash.

The Verification phase consists of launching test instances for each of the candidate images.  Once the instances are launched, a verification script is uploaded to each of the instances and executed.

The Promotion phase consists of cloning the candidate image into an image whose name has `-candidate` removed from the name and is a member of the image family bearing the same name as the `<build_name>`.  During the promotion phase, the process ensures that no more than two images exist in the image family.  If there are more than two images, the older ones are deleted.

# Repository Organization

This repository is organized into:
* a Packer template file (**template.pkr.hcl**) and additional files to upload into images
* a **verify** directory containing code to verify produced images
* a Justifications file (**justifications.json**)

## Packer Template

The Packer template file defines all of the images produced by this repository.  It also contains the provisioners used to build those images.  A manifest file is produced at the end of each build listing the produced artifacts.

For more information about the Packer template file, refer to the [documentation section](https://packer.io/docs) of the Packer website.

## **verify** Directory

The **verify** directory contains a verification test suite, that validates a produced image against all level 1 automated CIS Ubuntu 20.04 Benchmark sections.  The benchmark document can be downloaded for free from this [website](https://learn.cisecurity.org/benchmarks) (*you will be required to provide personal information*).  The verification test suite uses a Bash script to run all of the audit commands for each section.

## Justification File

The justification file allows specifying sections exempt for a given image.  When the verification test suite detects a failure in a section that's exempt, the failure is not counted, and the section is reported as **SKIPPED** rather than **FAILED**.

### Format

```json
{
    "<build_name>": [
        {"<section_number>": "<justification_text>"}
    ]
}
```
Where **<build_name>** is the name of the corresponding source block from the Packer template and the name field in the manifest document.

For example, in the Packer template file:

```hcl
source "googlecompute" "bastion"
```

or in the manifest document:

```json
{
    "builds": [
        {
            "name": "bastion",
      "builder_type": "googlecompute",
      [ >8 SNIP ]
}
```
the **<build_name>** would be `bastion`.
