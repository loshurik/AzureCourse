configuration CustomIIS
{
    Import-DscResource -Module xWebAdministration
    Import-DscResource -Module xNetworking
    
    node "localhost"
    {
        WindowsFeature IIS
        {
            Ensure      = "Present"
            Name        = "Web-Server"
        }
        
        xFirewall PortRule
        {
            Name            = "AllowIIsPort"
            DisplayName     = "Allow IIS website port"
            Ensure          = "Present"
            Action          = "Allow"
            Enabled         = "True"
            Profile         = ("Domain", "Private", "Public")
            Direction       = "Inbound"
            LocalPort       = ("8080")         
            Protocol        = "TCP"
            Description     = "Allow IIS website port" 
        }

        xWebsite DefaultSite  
        { 
            Ensure          = "Present" 
            Name            = "Default Web Site" 
            State           = "Started" 
            PhysicalPath    = "C:\inetpub\wwwroot" 
            DependsOn       = "[WindowsFeature]IIS" 
            BindingInfo     = MSFT_xWebBindingInformation 
                             { 
                               Protocol = "HTTP" 
                               Port     = 8080 
                             } 
        }
    }
}