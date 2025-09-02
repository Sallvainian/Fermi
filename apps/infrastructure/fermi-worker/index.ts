import * as pulumi from "@pulumi/pulumi";
import * as cloudflare from "@pulumi/cloudflare";

const config = new pulumi.Config();
const accountId = config.require("accountId");
const domain = config.require("domain");

const content = `export default {
  async fetch(request) {
    const options = { headers: { 'content-type': 'text/plain' } };
    return new Response("Hello World!", options);
  },
};`

const worker = new cloudflare.WorkersScript("hello-world-worker", {
  accountId: accountId,
  scriptName: "hello-world-worker",
  content: content,
  mainModule: "worker.js",
});

// Hardcode the zone ID
const zoneId = "761791055ac6eea3097d1631c0b3e7d4";

const route = new cloudflare.WorkersRoute("hello-world-route", {
  zoneId: zoneId,
  pattern: "hello-world." + domain,
  script: worker.scriptName,
});

const record = new cloudflare.DnsRecord("hello-world-record", {
  name: route.pattern,
  type: "A",
  content: "192.0.2.1",
  zoneId: zoneId,
  proxied: true,
  ttl: 1,
});

export const url = pulumi.interpolate`https://${record.name}`;