using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.Identity.Client;
using System.Text.Json;

namespace SPOListReaderRawGraph
{
    class Program
    {
        // Replace with your values
        
        private static string tenantId = "15154ad7-be1f-4ec1-886f-403223210051"; // e.g., mngenvmcap367749.onmicrosoft.com
        private static string clientId = "79f224e5-1624-455b-a219-1be8560631dc";
        private static string[] scopes = new[] { "Sites.Selected" };

        static async Task Main(string[] args)
        {
            // Authenticate using Device Code flow
            var app = PublicClientApplicationBuilder.Create(clientId)
                .WithTenantId(tenantId)
                .WithRedirectUri("http://localhost")
                .Build();

            var result = await app.AcquireTokenWithDeviceCode(scopes, deviceCodeCallback =>
            {
                Console.WriteLine(deviceCodeCallback.Message);
                return Task.CompletedTask;
            }).ExecuteAsync();

            string accessToken = result.AccessToken;

            using var httpClient = new HttpClient();
            httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            // SPO site and list details
            string siteHostname = "mngenvmcap367749.sharepoint.com";
            string sitePath = "/sites/test5";
            string listName = "list1";

            // 1. Get Site ID
            string siteUrl = $"https://graph.microsoft.com/v1.0/sites/{siteHostname}:{sitePath}";
            var siteResponse = await httpClient.GetStringAsync(siteUrl);
            var siteJson = JsonDocument.Parse(siteResponse);
            string siteId = siteJson.RootElement.GetProperty("id").GetString();

            // 2. Get List ID
            string listUrl = $"https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listName}";
            var listResponse = await httpClient.GetStringAsync(listUrl);
            var listJson = JsonDocument.Parse(listResponse);
            string listId = listJson.RootElement.GetProperty("id").GetString();

            // 3. Get List Items
            string itemsUrl = $"https://graph.microsoft.com/v1.0/sites/{siteId}/lists/{listId}/items?expand=fields";
            var itemsResponse = await httpClient.GetStringAsync(itemsUrl);
            var itemsJson = JsonDocument.Parse(itemsResponse);

            Console.WriteLine($"Items in list '{listName}':");
            foreach (var item in itemsJson.RootElement.GetProperty("value").EnumerateArray())
            {
                Console.WriteLine($"ID: {item.GetProperty("id").GetString()}");
                var fields = item.GetProperty("fields");
                foreach (var field in fields.EnumerateObject())
                {
                    Console.WriteLine($"{field.Name}: {field.Value}");
                }
                Console.WriteLine("-----------");
            }
        }
    }
}