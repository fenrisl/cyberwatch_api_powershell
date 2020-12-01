Function Get-IniContent {
    $ini = @{}
    switch -regex -file '..\api.conf'
    {
        "^\[(.+)\]$" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        "(.+?)\s*=\s*(.*)" # Key
        {
            if (!($section))
            {
                $section = "cyberwatch"
                $ini[$section] = @{}
            }
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    Return Get-CyberwatchApi -api_url $ini["cyberwatch"]["url"] -api_key $ini["cyberwatch"]["api_key"] -secret_key $ini["cyberwatch"]["secret_key"]
}


$client = Get-IniContent

$client.ping()
