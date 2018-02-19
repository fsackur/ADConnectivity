using System.Collections;
using System.Management.Automation;

namespace Dusty.Net
{
    public class P
    {
        P(PSCustomObject Module) {
            
        }
        //string Name = "Johnny";
        ScriptBlock script = ScriptBlock.Create("Write-Output 'hi'");

        public string GetName ()
        {
            
            script.Invoke(null);
            return output.ToString();
        }
    }

}