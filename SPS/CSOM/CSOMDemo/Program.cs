
using System;
using System.Security;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Identity.Client;
using Microsoft.SharePoint.Client;
using System.Configuration;
using Microsoft.Extensions.Configuration;


/*
 
dotnet add package Microsoft.SharePointOnline.CSOM
dotnet add package Microsoft.Identity.Client

*/
namespace CSOMDemo
{

    class Program
    {
        

        static IConfigurationRoot config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
            .Build();

        static string tenantName = config["SharePoint:TenantName"];
        static string tenantId = config["SharePoint:TenantId"];
        static string clientId = config["SharePoint:ClientId"];
        static string certPath = config["SharePoint:CertPath"];
        static string certPassword = config["SharePoint:CertPassword"];

        static string siteUrl = $"https://{tenantName}.sharepoint.com/sites/test4";

        static string GetAccessToken()
        {
            var cert = new X509Certificate2(certPath, certPassword, X509KeyStorageFlags.MachineKeySet);
            var authority = $"https://login.microsoftonline.com/{tenantId}";
            var scopes = new[] { $"https://{tenantName}.sharepoint.com/.default" };

            var app = ConfidentialClientApplicationBuilder.Create(clientId)
                .WithCertificate(cert)
                .WithAuthority(new Uri(authority))
                .Build();

            var result = app.AcquireTokenForClient(scopes).ExecuteAsync().Result;
            return result.AccessToken;
        }

        static void Main(string[] args)
        {
            assignSPFxCustomFormToAList();
            Console.ReadLine();
        }

        static async void assignSPFxCustomFormToAList()
        {
            string listTitle = "listDemo1";
            string contentTypeName = "Item";
            string componentId = "37154c9d-ea2b-476d-900f-a15e92a6a8de"; // Replace with your SPFx component ID 

            string accessToken = GetAccessToken();
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };

                List list = context.Web.Lists.GetByTitle(listTitle);

                //list.DefaultEditFormUrl = "/sites/test2/SitePages/CustomEditForm.aspx";
                var ContentTypeCollection = list.ContentTypes;
                context.Load(ContentTypeCollection);
                context.ExecuteQuery();
                ContentType targetContentType = null;
                foreach (var ct in ContentTypeCollection)
                {
                    if (ct.Name == contentTypeName)
                    {
                        targetContentType = ct;
                        break;
                    }
                }
                if(targetContentType != null)
                {
                    targetContentType.NewFormClientSideComponentId = componentId;
                    targetContentType.EditFormClientSideComponentId = componentId;
                    targetContentType.DisplayFormClientSideComponentId = componentId;
                    targetContentType.Update(false);
                    await context.ExecuteQueryAsync();
                    Console.WriteLine("Custom form assigned to the content type successfully.");
                }

              
            }
        }

        static void CSOMGetTile()
        {
            string accessToken = GetAccessToken();
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };
                Web web = context.Web;
                context.Load(web, w => w.Title);
                context.ExecuteQuery();
                Console.WriteLine($"Site Title: {web.Title}");
            }
        }

        static void GetAuthorEmail()
        {
            string accessToken = GetAccessToken();
            // Connect to SharePoint
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };
                List list = context.Web.Lists.GetByTitle("list1");



                var camlQuery = new CamlQuery
                {
                    ViewXml = "<View>" +
                                  "  <Query>" +
                                  "    <Where>" +
                                  "      <Eq>" +
                                  "        <FieldRef Name='ID'/>" +
                                  "        <Value Type='Text'>1</Value>" +
                                  "      </Eq>" +
                                  "    </Where>" +
                                  "  </Query>" +
                                  "  <RowLimit>4000</RowLimit>" +
                                  "</View>"
                };



                //CamlQuery query = CamlQuery.cre
                var items = list.GetItems(camlQuery);
                context.Load(items);
                context.ExecuteQuery();

                items[0].FieldValues.TryGetValue("Author", out var authorValue);
                if (authorValue is FieldUserValue userValue)
                {
                    //Console.WriteLine($"Author Email: {userValue.Email}");
                    int id = userValue.LookupId;
                    User authorUser = context.Web.GetUserById(id);
                    context.Load(authorUser);
                    context.ExecuteQuery();
                    Console.WriteLine($"Author Email: {authorUser.Email}");
                }


                printItems(items);
            }
        }

        private static void printItems(ListItemCollection items)
        {
            foreach (ListItem item in items)
            {
                foreach (var field in item.FieldValues)
                {
                    string fieldName = field.Key;
                    var value = field.Value;
                    if (fieldName == "Author")
                    {
                        if (value is FieldUserValue user)
                        {


                            Console.WriteLine($"Email: {user.Email}");
                            continue;
                        }
                    }
                }
            }
        }

        static void CSOMUpdateSiteAuthor(string newAuthorLogin)
        {
            string accessToken = GetAccessToken();
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };

                // Get the user by login name  
                User newAuthor = context.Web.EnsureUser(newAuthorLogin);
                context.Load(newAuthor);
                context.ExecuteQuery();

                // Update the site's author property using AllProperties  
                var web = context.Web;
                context.Load(web, w => w.AllProperties);
                context.ExecuteQuery();

                web.AllProperties["Author"] = newAuthor.LoginName;
                // web.AllProperties["Editor"] = newAuthor.LoginName; // Optionally update Editor as well  
                web.Update();
                context.ExecuteQuery();

                Console.WriteLine($"Site Author updated to: {newAuthorLogin}");
            }
        }

        static void CSOMGetSiteAuthor()
        {
            string accessToken = GetAccessToken();
            // Connect to SharePoint
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };
                Web web = context.Web;


                context.Load(web, w => w.Author);
                context.ExecuteQuery();
                Console.WriteLine($"Site Author: {web.Author.UserPrincipalName}");


            }
        }

        static void CSOMCreateSubSite()
        {
            string accessToken = GetAccessToken();
            // Connect to SharePoint  
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };

                // Create a new subsite  
                var webCreationInfo = new WebCreationInformation
                {
                    Title = "New Site",
                    Url = "/sites/NewSite2", // Relative URL for the subsite  
                    Description = "This is a new site created using CSOM.",
                    Language = 1033, // English  
                    UseSamePermissionsAsParentSite = true
                };

                Web newWeb = context.Web.Webs.Add(webCreationInfo);
                context.ExecuteQuery();
                Console.WriteLine($"New site created: {newWeb.Url}");
            }
        }


        static void CSOMRegisterRemoteEventReceiver()
        {

            string listTitle = "list2Csom";
            string accessToken = GetAccessToken();
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };
                List list = context.Web.Lists.GetByTitle(listTitle);
                // Define the event receiver
                EventReceiverDefinitionCreationInformation eventReceiver = new EventReceiverDefinitionCreationInformation
                {
                    EventType = EventReceiverType.ItemAdded,
                    ReceiverName = "CSMRER",
                    ReceiverUrl = "https://testCSOMAF/api/RemoteEventReceiver", // Replace with your Azure Function URL
                    SequenceNumber = 1000,
                    Synchronization = EventReceiverSynchronization.Synchronous
                };
                // Add the event receiver to the list
                list.EventReceivers.Add(eventReceiver);
                context.ExecuteQuery();
                Console.WriteLine("Remote event receiver registered successfully.");

            }
        }

        static void deleteEvcentReceiverByName()
        {
            string listTitle = "list2Csom";
            //string eventReceiverName = "CSMRER";
            string eventReceiverName = "RER-PNP";
            string accessToken = GetAccessToken();
            using (var context = new ClientContext(siteUrl))
            {
                context.ExecutingWebRequest += (sender, e) =>
                {
                    e.WebRequestExecutor.WebRequest.Headers.Add("Authorization", "Bearer " + accessToken);
                };
                List list = context.Web.Lists.GetByTitle(listTitle);
                context.Load(list.EventReceivers);
                context.ExecuteQuery();
                foreach (var receiver in list.EventReceivers)
                {
                    if (receiver.ReceiverName == eventReceiverName)
                    {
                        receiver.DeleteObject();
                        context.ExecuteQuery();
                        Console.WriteLine($"Event receiver '{eventReceiverName}' deleted successfully.");
                        break;
                    }
                }
            }
        }


    }

}
