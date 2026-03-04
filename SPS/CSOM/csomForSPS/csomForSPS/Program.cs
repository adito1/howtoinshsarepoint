using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.SharePoint.Client;

namespace csomForSPS
{
    internal class Program
    {
        static void Main(string[] args)
        {

            ClientContext context = new ClientContext("http://sp");

            // The SharePoint web at the URL.
            Web web = context.Web;

            // We want to retrieve the web's properties.
            context.Load(web);

            // Execute the query to the server.
            context.ExecuteQuery();
            string title = web.Title;
            Console.WriteLine("Web title: " + title);
            Console.ReadLine();
        }
    }
}
