<#
    .SYNOPSIS
        Converts MemoryStream to a string.

    .DESCRIPTION
        Converts MemoryStream to a string.

    .PARAMETER MemoryStream
        A System.IO.MemoryStream object for conversion.

    .PARAMETER Stream
        A System.IO.Stream object for conversion.

    .EXAMPLE
        $string = 'A string'
        $stream = [System.IO.MemoryStream]::new()
        $writer = [System.IO.StreamWriter]::new($stream)
        $writer.Write($string)
        $writer.Flush()

        ConvertFrom-MemoryStreamToString -MemoryStream $stream

        A string

    .EXAMPLE
        $string = 'A string'
        $stream = [System.IO.MemoryStream]::new()
        $writer = [System.IO.StreamWriter]::new($stream)
        $writer.Write($string)
        $writer.Flush()

        $stream | ConvertFrom-MemoryStreamToString

        A string

    .EXAMPLE
        $string1 = 'A string'
        $stream1 = [System.IO.MemoryStream]::new()
        $writer1 = [System.IO.StreamWriter]::new($stream1)
        $writer1.Write($string1)
        $writer1.Flush()

        $string2 = 'Another string'
        $stream2 = [System.IO.MemoryStream]::new()
        $writer2 = [System.IO.StreamWriter]::new($stream2)
        $writer2.Write($string2)
        $writer2.Flush()

        ConvertFrom-MemoryStreamToString -MemoryStream $stream1,$stream2

        A string
        Another string

    .EXAMPLE
        $string1 = 'A string'
        $stream1 = [System.IO.MemoryStream]::new()
        $writer1 = [System.IO.StreamWriter]::new($stream1)
        $writer1.Write($string1)
        $writer1.Flush()

        $string2 = 'Another string'
        $stream2 = [System.IO.MemoryStream]::new()
        $writer2 = [System.IO.StreamWriter]::new($stream2)
        $writer2.Write($string2)
        $writer2.Flush()

        $stream1,$stream2 | ConvertFrom-MemoryStreamToString

        A string
        Another string

    .OUTPUTS
        [String[]]

    .LINK
        http://convert.readthedocs.io/en/latest/functions/ConvertFrom-MemoryStreamToString/
#>
function ConvertFrom-MemoryStreamToString {
    [CmdletBinding(HelpUri = 'http://convert.readthedocs.io/en/latest/functions/ConvertFrom-MemoryStreamToString/')]
    [Alias('ConvertFrom-StreamToString')]
    param
    (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'MemoryStream')]
        [ValidateNotNullOrEmpty()]
        [System.IO.MemoryStream[]]
        $MemoryStream,

        [Parameter(
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'Stream')]
        [ValidateNotNullOrEmpty()]
        [System.IO.Stream[]]
        $Stream
    )

    begin {
        $userErrorActionPreference = $ErrorActionPreference
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'MemoryStream' {
                $inputObject = $MemoryStream
            }
            'Stream' {
                $inputObject = $Stream
            }
        }

        foreach ($object in $inputObject) {
            try {
                if ($PSCmdlet.ParameterSetName -eq 'MemoryStream') {
                    $object.Position = 0
                }
                $reader = [System.IO.StreamReader]::new($object)
                $reader.ReadToEnd()
            } catch {
                Write-Error -ErrorRecord $_ -ErrorAction $userErrorActionPreference
            } finally {
                if ($reader) {
                    #$reader.Dispose()
                }
            }
        }
    }
}
