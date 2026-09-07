#Requires -Version 5.1
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # DSC configurations legitimately use plain-text-adjacent patterns;
        # secrets are handled via SecureString parameters (see README).
        'PSAvoidUsingConvertToSecureStringWithPlainText'
    )
}
