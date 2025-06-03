$moduleName = 'Convert'
$function = $MyInvocation.MyCommand.Name.Split('.')[0]

$pathToManifest = [System.IO.Path]::Combine($PSScriptRoot, '..', '..', $moduleName, "$moduleName.psd1")
if (Get-Module -Name $moduleName -ErrorAction 'SilentlyContinue') {
    Remove-Module -Name $moduleName -Force
}
Import-Module $pathToManifest -Force

Describe -Name $function -Fixture {

    Context -Name 'Input/Output' -Fixture {
        It -Name "Converts a MemoryStream to a string" -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            $assertion = ConvertFrom-MemoryStreamToString -MemoryStream $stream
            $assertion | Should -BeExactly $string

            $stream.Dispose()
            $writer.Dispose()
        }
    }

    Context -Name 'Pipeline' -Fixture {
        It -Name 'Supports the Pipeline' -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            $assertion = $stream | ConvertFrom-MemoryStreamToString
            $assertion | Should -BeExactly $string

            $stream.Dispose()
            $writer.Dispose()
        }

        It -Name 'Supports the Pipeline with array input' -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            $stream2 = [System.IO.MemoryStream]::new()
            $writer2 = [System.IO.StreamWriter]::new($stream2)
            $writer2.Write($string)
            $writer2.Flush()
            $stream2

            $assertion = @($stream, $stream2) | ConvertFrom-MemoryStreamToString
            $assertion | Should -HaveCount 2

            $stream.Dispose()
            $stream2.Dispose()
            $writer.Dispose()
            $writer2.Dispose()
        }
    }

    Context -Name 'EAP' -Fixture {
        It -Name 'Supports SilentlyContinue' -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            # Disposing the StreamWriter will cause the function call to throw with 'Stream was not readable.'
            $writer.Dispose()

            $assertion = ConvertFrom-MemoryStreamToString -MemoryStream $stream -ErrorAction SilentlyContinue
            $assertion | Should -BeNullOrEmpty
        }

        It -Name 'Supports Stop' -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            # Disposing the StreamWriter will cause the function call to throw with either 'Cannot access a closed Stream.' or 'Stream was not readable.'
            $writer.Dispose()

            { ConvertFrom-MemoryStreamToString -MemoryStream $stream -ErrorAction Stop } | Should -Throw
        }

        It -Name 'Supports Continue' -Test {
            $string = 'ThisIsMyString'

            $stream = [System.IO.MemoryStream]::new()
            $writer = [System.IO.StreamWriter]::new($stream)
            $writer.Write($string)
            $writer.Flush()

            # Disposing the StreamWriter will cause the function call to throw with either 'Cannot access a closed Stream.' or 'Stream was not readable.'
            $writer.Dispose()

            $assertion = ConvertFrom-MemoryStreamToString -MemoryStream $stream -ErrorAction Continue 2>&1
            $assertion.Exception.InnerException.Message | Should -BeIn @('Cannot access a closed Stream.', 'Stream was not readable.')
        }
    }
}
