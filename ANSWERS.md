# Q1. Migrating from ingress-nginx to Gateway API

I would start by listing all 40 Ingresses and noting their hosts, paths, TLS
secrets, annotations, and any special rewrites, timeouts, or authentication.
Those annotations are the main risk because many are specific to ingress-nginx
and do not have a direct Gateway API equivalent.

Next I would choose a Gateway API controller that supports the features we
need, install its CRDs and controller alongside ingress-nginx, and create a
GatewayClass and Gateway. I would convert a low-risk application first, using
HTTPRoutes and the existing backend Services. Before moving production traffic,
I would test each route through the new controller with a temporary hostname
and check TLS, health checks, redirects, headers, and logs.

Once that works, I would move applications in small groups. I would keep both
controllers running during the migration and change DNS or load-balancer
routing gradually, so I can send traffic back to the old Ingress if something
breaks. I would remove ingress-nginx only after every route is accounted for
and the new Gateway has been stable.

I would expect problems with controller-specific annotations, path matching,
TLS secret references, and Gateway listener permissions. I would also watch
the Gateway and HTTPRoute status conditions: a route can exist but still not
be accepted or attached to its listener.

PS : i have done it in a production grade environment