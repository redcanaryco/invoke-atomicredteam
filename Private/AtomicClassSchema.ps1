class AtomicDependency {
    [String] $description
    [String] $prereq_command
    [String] $get_prereq_command
}

class AtomicInputArgument {
    [String] $description
    [String] $type
    [String] $default
}

class AtomicExecutorBase {
    [String] $name
    [Bool] $elevation_required

    # Implemented to facilitate improved PS object display
    [String] ToString() {
        return $this.Name
    }
}

class AtomicExecutorDefault : AtomicExecutorBase {
    [String] $command
    [String] $cleanup_command
}

class AtomicExecutorManual : AtomicExecutorBase {
    [String] $steps
    [String] $cleanup_command
}

class AtomicTest {
    [String] $name
    [String] $auto_generated_guid
    [String] $description
    [String[]] $supported_platforms
    # I wish this didn't have to be a hashtable but I don't
    # want to change the schema and introduce a breaking change.
    [Hashtable] $input_arguments
    [String] $dependency_executor_name
    [AtomicDependency[]] $dependencies
    [AtomicExecutorBase] $executor

    # Implemented to facilitate improved PS object display
    [String] ToString() {
        return $this.name
    }
}

class AtomicTechnique {
    [String[]] $attack_technique
    [String] $display_name
    [AtomicTest[]] $atomic_tests
}
