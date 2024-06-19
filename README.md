<p><img src="https://redcanary.com/wp-content/uploads/2023/05/Primary_Invoke-Atomic_Logo.png" width="500px" /></p>

Invoke-AtomicRedTeam is a PowerShell module to execute tests as defined in the [atomics folder](https://github.com/redcanaryco/atomic-red-team/tree/master/atomics) of Red Canary's Atomic Red Team project. The "atomics folder" contains a folder for each Technique defined by the [MITRE ATT&CK™ Framework](https://attack.mitre.org/matrices/enterprise/). Inside of each of these "T#" folders you'll find a **yaml** file that defines the attack procedures for each atomic test as well as an easier to read markdown (**md**) version of the same data.

* Executing atomic tests may leave your system in an undesirable state. You are responsible for understanding what a test does before executing.

* Ensure you have permission to test before you begin.

* It is recommended to set up a test machine for atomic test execution that is similar to the build in your environment. Be sure you have your collection/EDR solution in place, and that the endpoint is checking in and active.

See the Wiki for complete [Installation and Usage instructions](https://github.com/redcanaryco/invoke-atomicredteam/wiki).

Note: This execution frameworks works on Windows, MacOS and Linux. If using on MacOS or Linux you must install PowerShell Core first.

### Contributing
Ensure proper byte order marks (BOM) are maintained when utilizing a PowerShell linter with the following steps:

```shell
pip3 install pre-commit
pre-commit install
pre-commit install-hooks
```

By following these instructions, pre-commit hooks will be activated, automatically resolving any byte order mark issues within your PowerShell files. Additionally, these hooks will be triggered prior to committing code to your GitHub repository, ensuring consistent formatting and adherence to best practices.

You can also trigger pre-commit hooks manually by

```shell
pre-commit run --all-files
```