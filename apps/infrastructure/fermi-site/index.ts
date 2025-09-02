import * as pulumi from "@pulumi/pulumi";
import * as cloudflare from "@pulumi/cloudflare";

const config = new pulumi.Config();
const accountId = config.require("accountId");
const domain = config.require("domain");

// Create a Cloudflare resource (Zone)
const zone = new cloudflare.Zone("my-zone", {
  account: {
    id: accountId,
  },
  name: domain,
  type: "full",
}, {
  protect: true,
});

// Add a DNS Record
const record = new cloudflare.DnsRecord("my-record", {
    zoneId: zone.id,
    name: domain,
    content: "192.0.2.1",
    type: "A",
    proxied: true,
    ttl: 1,
  });

export const zoneId = zone.id;
export const nameservers = zone.nameServers;
export const status = zone.status;