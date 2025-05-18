TITLE: Defining a ResourceGraphDefinition for an Application
DESCRIPTION: This YAML snippet defines a ResourceGraphDefinition named 'my-application' in kro. It specifies a schema for user input (name, image, ingress.enabled) and defines the Kubernetes resources (Deployment, Service, Ingress) that will be created based on this schema. It demonstrates how to use schema values and references between resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/getting-started/02-deploy-a-resource-graph-definition.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: my-application
spec:
  # kro uses this simple schema to create your CRD schema and apply it
  # The schema defines what users can provide when they instantiate the RGD (create an instance).
  schema:
    apiVersion: v1alpha1
    kind: Application
    spec:
      # Spec fields that users can provide.
      name: string
      image: string | default="nginx"
      ingress:
        enabled: boolean | default=false
    status:
      # Fields the controller will inject into instances status.
      deploymentConditions: ${deployment.status.conditions}
      availableReplicas: ${deployment.status.availableReplicas}

  # Define the resources this API will manage.
  resources:
    - id: deployment
      template:
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ${schema.spec.name} # Use the name provided by user
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: ${schema.spec.name}
          template:
            metadata:
              labels:
                app: ${schema.spec.name}
            spec:
              containers:
                - name: ${schema.spec.name}
                  image: ${schema.spec.image} # Use the image provided by user
                  ports:
                    - containerPort: 80

    - id: service
      template:
        apiVersion: v1
        kind: Service
        metadata:
          name: ${schema.spec.name}-service
        spec:
          selector: ${deployment.spec.selector.matchLabels} # Use the deployment selector
          ports:
            - protocol: TCP
              port: 80
              targetPort: 80

    - id: ingress
      includeWhen:
        - ${schema.spec.ingress.enabled} # Only include if the user wants to create an Ingress
      template:
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ${schema.spec.name}-ingress
          annotations:
            kubernetes.io/ingress.class: alb
            alb.ingress.kubernetes.io/scheme: internet-facing
            alb.ingress.kubernetes.io/target-type: ip
            alb.ingress.kubernetes.io/healthcheck-path: /health
            alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
            alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=60
        spec:
          rules:
            - http:
                paths:
                  - path: "/"
                    pathType: Prefix
                    backend:
                      service:
                        name: ${service.metadata.name} # Use the service name
                        port:
                          number: 80
```

----------------------------------------

TITLE: Define KRO ResourceGraph for Pod and RDS Postgres
DESCRIPTION: This YAML snippet defines a KRO ResourceGraphDefinition resource. It specifies a schema for inputs (application name, image, location) and defines two resources: an AWS RDS DBInstance (Postgres) and a Kubernetes Pod. The Pod's environment variable 'POSTGRESS_ENDPOINT' is dynamically set using the status output of the provisioned DBInstance.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/aws/pod-rds-dbinstance.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: deploymentandawspostgres
spec:
  # CRD Definition
  schema:
    apiVersion: v1alpha1
    kind: DeploymentAndAWSPostgres
    spec:
      applicationName: string
      image: string
      location: string

  # Resources
  resources:
    - id: dbinstance
      template:
        apiVersion: rds.services.k8s.aws/v1alpha1
        kind: DBInstance
        metadata:
          name: ${schema.spec.applicationName}-dbinstance
        spec:
          # need to specify the required fields (e.g masterUsername, masterPassword)
          engine: postgres
          dbInstanceIdentifier: ${schema.spec.applicationName}-dbinstance
          allocatedStorage: 20
          dbInstanceClass: db.t3.micro

    - id: pod
      template:
        apiVersion: v1
        kind: Pod
        metadata:
          name: ${schema.spec.applicationName}-pod
        spec:
          containers:
            - name: container1
              image: ${schema.spec.image}
              env:
                - name: POSTGRESS_ENDPOINT
                  value: ${dbinstance.status.endpoint.address}
```

----------------------------------------

TITLE: deploymentservice-rg.yaml
DESCRIPTION: This YAML defines a kro.run ResourceGraphDefinition for a web application. It specifies a schema for a DeploymentService and includes templates for a Kubernetes Deployment and Service, both named based on the schema's 'name' property and configured to use the Nginx image.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/basic/web-app.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: deploymentservice
spec:
  schema:
    apiVersion: v1alpha1
    kind: DeploymentService
    spec:
      name: string
  resources:
    - id: deployment
      template:
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ${schema.spec.name}
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: deployment
          template:
            metadata:
              labels:
                app: deployment
            spec:
              containers:
                - name: ${schema.spec.name}-deployment
                  image: nginx
                  ports:
                    - containerPort: 80
    - id: service
      template:
        apiVersion: v1
        kind: Service
        metadata:
          name: ${schema.spec.name}
        spec:
          selector:
            app: deployment
          ports:
            - protocol: TCP
              port: 80
              targetPort: 80
```

----------------------------------------

TITLE: CloudSQL ResourceGraphDefinition (RGD) Configuration
DESCRIPTION: Defines the `cloudsql.kro.run` ResourceGraphDefinition in YAML format. It specifies the schema for the user-facing CloudSQL custom resource and lists the underlying Google Cloud resources (like Service Usage, KMS, IAM) that `kro.run` will manage to fulfill the CloudSQL definition.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/gcp/cloud-sql.md#_snippet_5

LANGUAGE: YAML
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: cloudsql.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: CloudSQL
    spec:
      name: string
      project: string
      primaryRegion: string
      replicaRegion: string
    status:
      connectionName: ${sqlPrimary.status.connectionName}
      ipAddress: ${sqlPrimary.status.firstIpAddress}
  resources:
  - id: cloudkmsEnable
    template:
      apiVersion: serviceusage.cnrm.cloud.google.com/v1beta1
      kind: Service
      metadata:
        annotations:
          cnrm.cloud.google.com/deletion-policy: "abandon"
          cnrm.cloud.google.com/disable-dependent-services: "false"
        name: cloudkms-enablement
      spec:
        resourceID: cloudkms.googleapis.com
  - id: iamEnable
    template:
      apiVersion: iam.cnrm.cloud.google.com/v1beta1
      kind: IAMPolicyMember
      metadata:
        annotations:
          cnrm.cloud.google.com/deletion-policy: "abandon"
          cnrm.cloud.google.com/disable-dependent-services: "false"
        name: iam-enablement
      spec:
        resourceID: iam.googleapis.com
  - id: serviceUsageEnable
    template:
      apiVersion: serviceusage.cnrm.cloud.google.com/v1beta1
      kind: Service
      metadata:
        annotations:
          cnrm.cloud.google.com/deletion-policy: "abandon"
          cnrm.cloud.google.com/disable-dependent-services: "false"
        name: serviceusage-enablement
      spec:
        resourceID: serviceusage.googleapis.com
  - id: sqlAdminEnable
    template:
      apiVersion: serviceusage.cnrm.cloud.google.com/v1beta1
      kind: Service
      metadata:
        annotations:
          cnrm.cloud.google.com/deletion-policy: "abandon"
          cnrm.cloud.google.com/disable-dependent-services: "false"
        name: sqladmin-enablement
      spec:
        resourceID: sqladmin.googleapis.com
  - id: serviceidentity
    template:
      apiVersion: serviceusage.cnrm.cloud.google.com/v1beta1
      kind: ServiceIdentity
      metadata:
        labels:
          enabled-service: ${serviceUsageEnable.metadata.name}
        name: sqladmin.googleapis.com
      spec:
        projectRef:
          external: ${schema.spec.project}
  - id: keyringPrimary
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSKeyRing
      metadata:
        labels:
          enabled-service: ${cloudkmsEnable.metadata.name}
        name: ${schema.spec.name}-primary
      spec:
        location: ${schema.spec.primaryRegion}
  - id: keyringReplica
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSKeyRing
      metadata:
        labels:
          enabled-service: ${cloudkmsEnable.metadata.name}
        name: ${schema.spec.name}-replica
      spec:
        location: ${schema.spec.replicaRegion}
  - id: kmskeyPrimary
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSCryptoKey
      metadata:
        labels:
          enabled-service: ${cloudkmsEnable.metadata.name}
          failure-zone: ${schema.spec.primaryRegion}
        name: ${schema.spec.name}-primary
      spec:
        keyRingRef:
          name: ${keyringPrimary.metadata.name}
          #namespace: {{ cloudsqls.metadata.namespace }}
        purpose: ENCRYPT_DECRYPT
        versionTemplate:
          algorithm: GOOGLE_SYMMETRIC_ENCRYPTION
          protectionLevel: SOFTWARE
        importOnly: false
  - id: kmskeyReplica
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSCryptoKey
      metadata:
        labels:
          enabled-service: ${cloudkmsEnable.metadata.name}
          failure-zone: ${schema.spec.replicaRegion}
        name: ${schema.spec.name}-replica
      spec:
        keyRingRef:
          name: ${keyringReplica.metadata.name}
          #namespace: {{ cloudsqls.metadata.namespace }}
        purpose: ENCRYPT_DECRYPT
        versionTemplate:
          algorithm: GOOGLE_SYMMETRIC_ENCRYPTION
          protectionLevel: SOFTWARE
        importOnly: false
  - id: iampolicymemberPrimary
    template:
      apiVersion: iam.cnrm.cloud.google.com/v1beta1
      kind: IAMPolicyMember
      metadata:
        labels:
          enabled-service: ${iamEnable.metadata.name}
        name: sql-kms-${schema.spec.primaryRegion}-policybinding
      spec:
        member: serviceAccount:${serviceidentity.status.email}
        role: roles/cloudkms.cryptoKeyEncrypterDecrypter
```

----------------------------------------

TITLE: ResourceGraphDefinition for AWS Valkey Cluster (YAML)
DESCRIPTION: Defines a Kro.run ResourceGraphDefinition resource that orchestrates the creation of AWS resources required for a Valkey cluster: a NetworkingStack, CacheSubnetGroup, SecurityGroup, and the ElastiCache CacheCluster itself. It uses templating to link resource outputs (like VPC ID, subnet IDs, security group ID, subnet group name) as inputs for subsequent resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/aws/ack-valkey-cachecluster.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: valkey.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: Valkey
    spec:
      name: string
    status:
      csgARN: ${cacheSubnetGroup.status.ackResourceMetadata.arn}
      subnets: ${cacheSubnetGroup.status.subnets}
      clusterARN: ${valkey.status.ackResourceMetadata.arn}
  resources:
    - id: networkingStack
      template:
        apiVersion: kro.run/v1alpha1
        kind: NetworkingStack
        metadata:
          name: ${schema.spec.name}-networking-stack
        spec:
          name: ${schema.spec.name}-networking-stack
    - id: cacheSubnetGroup
      template:
        apiVersion: elasticache.services.k8s.aws/v1alpha1
        kind: CacheSubnetGroup
        metadata:
          name: ${schema.spec.name}-valkey-subnet-group
        spec:
          cacheSubnetGroupDescription: "Valkey ElastiCache subnet group"
          cacheSubnetGroupName: ${schema.spec.name}-valkey-subnet-group
          subnetIDs:
            - ${networkingStack.status.networkingInfo.subnetAZA}
            - ${networkingStack.status.networkingInfo.subnetAZB}
            - ${networkingStack.status.networkingInfo.subnetAZC}
    - id: sg
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: SecurityGroup
        metadata:
          name: ${schema.spec.name}-valkey-sg
        spec:
          name: ${schema.spec.name}-valkey-sg
          description: "Valkey ElastiCache security group"
          vpcID: ${networkingStack.status.networkingInfo.vpcID}
          ingressRules:
            - fromPort: 6379
              toPort: 6379
              ipProtocol: tcp
              ipRanges:
                - cidrIP: 0.0.0.0/0
    - id: valkey
      template:
        apiVersion: elasticache.services.k8s.aws/v1alpha1
        kind: CacheCluster
        metadata:
          name: ${schema.spec.name}-valkey
        spec:
          cacheClusterID: vote-valkey-cluster
          cacheNodeType: cache.t3.micro
          cacheSubnetGroupName: ${schema.spec.name}-valkey-subnet-group
          engine: valkey
          engineVersion: "8.x"
          numCacheNodes: 1
          port: 6379
          securityGroupIDs:
            - ${sg.status.id}
```

----------------------------------------

TITLE: ResourceGraphDefinition (RGD) for GKE Cluster
DESCRIPTION: Defines a Kubernetes ResourceGraphDefinition (RGD) for provisioning a Google Kubernetes Engine (GKE) cluster and related resources (network, subnet, pubsub topic, kms keyring/key, nodepool) using Google Cloud Config Connector (CNRM). It specifies the schema for user input and the templates for creating the underlying GCP resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/gcp/gke-cluster.md#_snippet_5

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: gkecluster.kro.run
spec:
  schema:
    apiVersion: v1alpha1
    kind: GKECluster
    spec:
      name: string
      nodepool: string
      maxnodes: integer
      location: string
    status:
      masterVersion: ${cluster.status.masterVersion}
  resources:
  - id: network
    template:
      apiVersion: compute.cnrm.cloud.google.com/v1beta1
      kind: ComputeNetwork
      metadata:
        labels:
          source: "gkecluster"
        name: ${schema.spec.name}
      spec:
        #routingMode: GLOBAL
        #deleteDefaultRoutesOnCreate: false
        routingMode: REGIONAL
        autoCreateSubnetworks: false
  - id: subnet
    template:
      apiVersion: compute.cnrm.cloud.google.com/v1beta1
      kind: ComputeSubnetwork
      metadata:
        labels:
          source: "gkecluster"
        name: ${network.metadata.name}
      spec:
        ipCidrRange: 10.2.0.0/16
        #ipCidrRange: 10.10.90.0/24
        region: ${schema.spec.location}
        networkRef:
          name: ${schema.spec.name}
        #privateIpGoogleAccess: true
  - id: topic
    template:
      apiVersion: pubsub.cnrm.cloud.google.com/v1beta1
      kind: PubSubTopic
      metadata:
        labels:
          source: "gkecluster"
        name: ${subnet.metadata.name}
  - id: keyring
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSKeyRing
      metadata:
        labels:
          source: "gkecluster"
        name: ${topic.metadata.name}
      spec:
        location: ${schema.spec.location}
  - id: key
    template:
      apiVersion: kms.cnrm.cloud.google.com/v1beta1
      kind: KMSCryptoKey
      metadata:
        labels:
          source: "gkecluster"
        name: ${keyring.metadata.name}
      spec:
        keyRingRef:
          name: ${schema.spec.name}
        purpose: ASYMMETRIC_SIGN
        versionTemplate:
          algorithm: EC_SIGN_P384_SHA384
          protectionLevel: SOFTWARE
        importOnly: false
  - id: nodepool
    template:
      apiVersion: container.cnrm.cloud.google.com/v1beta1
      kind: ContainerNodePool
      metadata:
        labels:
          source: "gkecluster"
        name: ${cluster.metadata.name}
      spec:
        location: ${schema.spec.location}
        autoscaling:
          minNodeCount: 1
          maxNodeCount: ${schema.spec.maxnodes}
        nodeConfig:
          machineType: n1-standard-1
          diskSizeGb: 100
          diskType: pd-standard
          #taint:
          #- effect: NO_SCHEDULE
          #  key: originalKey
          #  value: originalValue
        clusterRef:
          name: ${schema.spec.name}
  - id: cluster
    template:
      apiVersion: container.cnrm.cloud.google.com/v1beta1
      kind: ContainerCluster
      metadata:
        #annotations:
        #  cnrm.cloud.google.com/remove-default-node-pool: "false"
        labels:
          source: "gkecluster"
        name: ${key.metadata.name}
      spec:
        location: ${schema.spec.location}
        initialNodeCount: 1
        networkRef:
          name: ${schema.spec.name}
        subnetworkRef:
          name: ${schema.spec.name}
        ipAllocationPolicy:
          clusterIpv4CidrBlock: /20
          servicesIpv4CidrBlock: /20
        #masterAuth:
        #  clientCertificateConfig:
        #    issueClientCertificate: false
        #workloadIdentityConfig:
        #  # Workload Identity supports only a single namespace based on your project name.
        #  # Replace ${PROJECT_ID?} below with your project ID.
        #  workloadPool: ${PROJECT_ID?}.svc.id.goog      
        notificationConfig:
          pubsub:
            enabled: true
            topicRef:
              name: ${schema.spec.name}
        loggingConfig:
          enableComponents:
            - "SYSTEM_COMPONENTS"
            - "WORKLOADS"
        monitoringConfig:
          enableComponents:
            - "SYSTEM_COMPONENTS"
            - "APISERVER"
          managedPrometheus:
            enabled: true
        clusterAutoscaling:
          enabled: true
          autoscalingProfile: BALANCED
          resourceLimits:
            - resourceType: cpu
              maximum: 100
              minimum: 10
            - resourceType: memory
              maximum: 1000
              minimum: 100
          autoProvisioningDefaults:
            bootDiskKMSKeyRef:
              name: ${schema.spec.name}
        nodeConfig:
          linuxNodeConfig:
            sysctls:
              net.core.somaxconn: "4096"
```

----------------------------------------

TITLE: Defining Structured and Nested Types in kro Schema (YAML)
DESCRIPTION: Shows how to define complex objects by nesting fields. It includes examples of a simple structure and a nested structure containing another object and an array.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/10-simple-schema.md#_snippet_2

LANGUAGE: yaml
CODE:
```
# Simple structure
address:
  street: string
  city: string
  zipcode: string

# Nested structures
user:
  name: string
  address: # Nested object
    street: string
    city: string
  contacts: "[]string" # Array of strings
```

----------------------------------------

TITLE: Define EKS Cluster Resource Graph (YAML)
DESCRIPTION: This YAML snippet defines a kro.run ResourceGraphDefinition for creating an AWS EKS cluster. It specifies the desired state of the EKS cluster and its related AWS resources (VPC, subnets, gateways, roles) using ACK resource templates, defining dependencies and output mappings between resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/aws/ack-eks-cluster.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: ekscluster.kro.run
spec:
  # CRD Schema
  schema:
    apiVersion: v1alpha1
    kind: EKSCluster
    spec:
      name: string
      version: string
    status:
      networkingInfo:
        vpcID: ${clusterVPC.status.vpcID}
        subnetAZA: ${clusterSubnetA.status.subnetID}
        subnetAZB: ${clusterSubnetB.status.subnetID}
      clusterARN: ${cluster.status.ackResourceMetadata.arn}
  # resources
  resources:
    - id: clusterVPC
      readyWhen:
        - ${clusterVPC.status.state == "available"}
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: VPC
        metadata:
          name: kro-cluster-vpc
        spec:
          cidrBlocks:
            - 192.168.0.0/16
          enableDNSSupport: true
          enableDNSHostnames: true
    - id: clusterElasticIPAddress
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: ElasticIPAddress
        metadata:
          name: kro-cluster-eip
        spec: {}
    - id: clusterInternetGateway
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: InternetGateway
        metadata:
          name: kro-cluster-igw
        spec:
          vpc: ${clusterVPC.status.vpcID}
    - id: clusterRouteTable
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: RouteTable
        metadata:
          name: kro-cluster-public-route-table
        spec:
          vpcID: ${clusterVPC.status.vpcID}
          routes:
            - destinationCIDRBlock: 0.0.0.0/0
              gatewayID: ${clusterInternetGateway.status.internetGatewayID}
    - id: clusterSubnetA
      readyWhen:
        - ${clusterSubnetA.status.state == "available"}
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: Subnet
        metadata:
          name: kro-cluster-public-subnet1
        spec:
          availabilityZone: us-west-2a
          cidrBlock: 192.168.0.0/18
          vpcID: ${clusterVPC.status.vpcID}
          routeTables:
            - ${clusterRouteTable.status.routeTableID}
          mapPublicIPOnLaunch: true
    - id: clusterSubnetB
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: Subnet
        metadata:
          name: kro-cluster-public-subnet2
        spec:
          availabilityZone: us-west-2b
          cidrBlock: 192.168.64.0/18
          vpcID: ${clusterVPC.status.vpcID}
          routeTables:
            - ${clusterRouteTable.status.routeTableID}
          mapPublicIPOnLaunch: true
    - id: clusterNATGateway
      template:
        apiVersion: ec2.services.k8s.aws/v1alpha1
        kind: NATGateway
        metadata:
          name: kro-cluster-natgateway1
        spec:
          subnetID: ${clusterSubnetB.status.subnetID}
          allocationID: ${clusterElasticIPAddress.status.allocationID}
    - id: clusterRole
      template:
        apiVersion: iam.services.k8s.aws/v1alpha1
        kind: Role
        metadata:
          name: kro-cluster-role
        spec:
          name: kro-cluster-role
          description: "kro created cluster cluster role"
          policies:
            - arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
          assumeRolePolicyDocument: |
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Principal": {
                    "Service": "eks.amazonaws.com"
                  },
                  "Action": "sts:AssumeRole"
                }
              ]
            }
    - id: clusterNodeRole
      template:
        apiVersion: iam.services.k8s.aws/v1alpha1
        kind: Role
        metadata:
          name: kro-cluster-node-role
        spec:
          name: kro-cluster-node-role
          description: "kro created cluster node role"
          policies:
            - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
            - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
            - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
          assumeRolePolicyDocument: |
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Principal": {
                    "Service": "ec2.amazonaws.com"
                  },
                  "Action": "sts:AssumeRole"
                }
              ]
            }
    - id: clusterAdminRole
      template:
        apiVersion: iam.services.k8s.aws/v1alpha1
        kind: Role
        metadata:
          name: kro-cluster-pia-role
        spec:
          name: kro-cluster-pia-role
          description: "kro created cluster admin pia role"
          policies:
            - arn:aws:iam::aws:policy/AdministratorAccess
          assumeRolePolicyDocument: |
            {
                "Version": "2012-10-17",
                "Statement": [

```

----------------------------------------

TITLE: ResourceGraphDefinition for Web Application
DESCRIPTION: This YAML snippet defines a kro.run ResourceGraphDefinition (RGD) named 'my-application'. It specifies a schema for user input (name, image, ingress enabled) and defines the Kubernetes resources (Deployment, Service, Ingress) that the RGD will manage based on the provided schema values and dependencies between resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/basic/web-app-ingress.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: my-application
spec:
  # kro uses this simple schema to create your CRD schema and apply it
  # The schema defines what users can provide when they instantiate the RGD (create an instance).
  schema:
    apiVersion: v1alpha1
    kind: Application
    spec:
      # Spec fields that users can provide.
      name: string
      image: string | default="nginx"
      ingress:
        enabled: boolean | default=false
    status:
      # Fields the controller will inject into instances status.
      deploymentConditions: ${deployment.status.conditions}
      availableReplicas: ${deployment.status.availableReplicas}

  # Define the resources this API will manage.
  resources:
    - id: deployment
      template:
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: ${schema.spec.name} # Use the name provided by user
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: ${schema.spec.name}
          template:
            metadata:
              labels:
                app: ${schema.spec.name}
            spec:
              containers:
                - name: ${schema.spec.name}
                  image: ${schema.spec.image} # Use the image provided by user
                  ports:
                    - containerPort: 80

    - id: service
      template:
        apiVersion: v1
        kind: Service
        metadata:
          name: ${schema.spec.name}-service
        spec:
          selector: ${deployment.spec.selector.matchLabels} # Use the deployment selector
          ports:
            - protocol: TCP
              port: 80
              targetPort: 80

    - id: ingress
      includeWhen:
        - ${schema.spec.ingress.enabled} # Only include if the user wants to create an Ingress
      template:
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: ${schema.spec.name}-ingress
          annotations:
            kubernetes.io/ingress.class: alb
            alb.ingress.kubernetes.io/scheme: internet-facing
            alb.ingress.kubernetes.io/target-type: ip
            alb.ingress.kubernetes.io/healthcheck-path: /health
            alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
            alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=60
        spec:
          rules:
            - http:
                paths:
                  - path: "/"
                    pathType: Prefix
                    backend:
                      service:
                        name: ${service.metadata.name} # Use the service name
                        port:
                          number: 80
```

----------------------------------------

TITLE: Define KRO CloudSQL Resource (YAML)
DESCRIPTION: Defines a KRO CloudSQL custom resource to provision a GCP Cloud SQL instance with a replica in a different region using Config Connector. Specifies the instance name, GCP project, and primary/replica regions.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/examples/gcp/cloud-sql.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: CloudSQL
metadata:
  name: demo
  namespace: config-connector
spec:
  name: demo
  project: my-gcp-project
  primaryRegion: us-central1
  replicaRegion: us-west1
```

----------------------------------------

TITLE: Defining Status Fields in KRO RGD (YAML)
DESCRIPTION: Defines status fields within a KRO Resource Group Definition (RGD) to expose the state of underlying resources like certificate validation status, certificate ARN, and load balancer hostname. These fields can be consumed by other RGDs.
SOURCE: https://github.com/kro-run/kro/blob/main/examples/aws/ingress-triangle/README.md#_snippet_0

LANGUAGE: YAML
CODE:
```
# Status fields show how we track and expose resource states to use to other RGDs
status:
  validationStatus: ${certificateResource.status.domainValidations[0].validationStatus}
  certificateARN:  ${certificateResource.status.ackResourceMetadata.arn}
  loadBalancerARN: ${ingress.status.loadBalancer.ingress[0].hostname}
```

----------------------------------------

TITLE: Deploy KRO to Kind Cluster with Ko (Helper)
DESCRIPTION: Uses a Makefile target to automate the process of recreating a Kind cluster, installing CRDs, building the container image with ko, and deploying the controller via Helm.
SOURCE: https://github.com/kro-run/kro/blob/main/docs/developer-getting-started.md#_snippet_4

LANGUAGE: sh
CODE:
```
KIND_CLUSTER_NAME=kro make deploy-kind
```

----------------------------------------

TITLE: Defining a kro WebApplication Instance (YAML)
DESCRIPTION: This YAML snippet shows an example definition for a 'WebApplication' instance. It specifies the API version, kind, metadata (name), and the desired configuration under the 'spec' field, including the application name, container image, and ingress settings.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/15-instances.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: v1alpha1
kind: WebApplication
metadata:
  name: my-app
spec:
  name: web-app
  image: nginx:latest
  ingress:
    enabled: true
```

----------------------------------------

TITLE: Applying Validation and Documentation Markers (YAML)
DESCRIPTION: Illustrates how to add validation and documentation markers like `required`, `default`, `description`, `minimum`, `maximum`, and `enum` to fields using the `|` separator.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/10-simple-schema.md#_snippet_6

LANGUAGE: yaml
CODE:
```
name: string | required=true default="app" description="Application name"
replicas: integer | default=3 minimum=1 maximum=10
mode: string | enum="debug,info,warn,error" default="info"
```

----------------------------------------

TITLE: Defining ResourceGraphDefinition Schema (YAML)
DESCRIPTION: Shows how to define the schema for a ResourceGraphDefinition, specifying user-configurable fields (spec), status fields populated by kro, and validation rules using CEL expressions.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/00-resource-group-definitions.md#_snippet_1

LANGUAGE: yaml
CODE:
```
schema:
  apiVersion: v1alpha1
  kind: WebApplication # This becomes your new API type
  spec:
    # Fields users can configure using a simple, straightforward syntax
    name: string
    image: string | default="nginx"
    replicas: integer | default=3
    ingress:
      enabled: boolean | default=false

  status:
    # Fields kro will populate automatically from your resources
    # Types are inferred from these CEL expressions
    availableReplicas: ${deployment.status.availableReplicas}
    conditions: ${deployment.status.conditions}

  validation:
    # Validating admission policies added to the new API type's CRD
    - expression: "${ self.image == 'nginx' || !self.ingress.enabled }"
      message: "Only nginx based applications can have ingress enabled"
```

----------------------------------------

TITLE: Basic ResourceGraphDefinition Structure (YAML)
DESCRIPTION: Illustrates the fundamental structure of a ResourceGraphDefinition, including metadata, spec, schema, and resources sections.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/00-resource-group-definitions.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: my-resourcegraphdefinition # Metadata section
spec:
  schema: # Define your API
    apiVersion: v1alpha1 # API version
    kind: MyAPI # API kind
    spec: {} # fields users can configure
    status: {} # fields kro will populate

  # Define the resources kro will manage
  resources:
    - id: resource1
      # declare your resources along with default values and variables
      template: {}
```

----------------------------------------

TITLE: Defining a Simple kro API Schema in YAML
DESCRIPTION: This example demonstrates the structure of a `ResourceGraphDefinition` in kro, including basic, structured, array, and map types within the `spec.schema.spec` section, custom types in `spec.schema.types`, and status field definitions referencing external resources.
SOURCE: https://github.com/kro-run/kro/blob/main/website/docs/docs/concepts/10-simple-schema.md#_snippet_0

LANGUAGE: yaml
CODE:
```
apiVersion: kro.run/v1alpha1
kind: ResourceGraphDefinition
metadata:
  name: web-application
spec:
  schema:
    apiVersion: v1alpha1
    kind: WebApplication
    spec:
      # Basic types
      name: string | required=true description="My Name"
      replicas: integer | default=1 minimum=1 maximum=100
      image: string | required=true

      # Structured type
      ingress:
        enabled: boolean | default=false
        host: string | default="example.com"
        path: string | default="/"

      # Array type
      ports: "[]integer"

      # Map type
      env: "map[string]mytype"

    # Custom Types
    types:
      myType:
        value1: string | required=true
        value2: integer | default=42

    status:
      # Status fields with auto-inferred types
      availableReplicas: ${deployment.status.availableReplicas}
      serviceEndpoint: ${service.status.loadBalancer.ingress[0].hostname}
```

----------------------------------------

TITLE: Installing the ResourceGraphDefinition (Administrator)
DESCRIPTION: This shell command is executed by the Platform Administrator to apply the ResourceGraphDefinition (RGD) YAML file to the Kubernetes cluster. This makes the custom GKECluster resource type available for end users to create instances.
SOURCE: https://github.com/kro-run/kro/blob/main/examples/gcp/gke-cluster/README.md#_snippet_3

LANGUAGE: shell
CODE:
```
kubectl apply -f rgd.yaml
```

----------------------------------------

TITLE: Install KRO using Helm
DESCRIPTION: Installs the KRO (Kubernetes Resource Orchestrator) using Helm, fetching the latest version from the GitHub releases and deploying it into the 'kro' namespace.
SOURCE: https://github.com/kro-run/kro/blob/main/examples/apigateway/vpc-lattice/README.md#_snippet_0

LANGUAGE: bash
CODE:
```
export KRO_VERSION=$(curl -sL \
    https://api.github.com/repos/kro-run/kro/releases/latest | \
    jq -r '.tag_name | ltrimstr("v")'
  )
helm install kro oci://ghcr.io/kro-run/kro/kro \
  --namespace kro \
  --create-namespace \
  --version=${KRO_VERSION}
```

----------------------------------------

TITLE: Conditional Resource Dependency in KRO RGD (YAML)
DESCRIPTION: Demonstrates how to create a conditional dependency in a KRO RGD using status fields. The AWS Load Balancer Controller annotation for the certificate ARN is set only when the certificate validation status is 'SUCCESS', preventing the Ingress from using an invalid certificate ARN.
SOURCE: https://github.com/kro-run/kro/blob/main/examples/aws/ingress-triangle/README.md#_snippet_1

LANGUAGE: YAML
CODE:
```
# Ingress waits for certificate validation before using the ARN
annotations:
  alb.ingress.kubernetes.io/certificate-arn: '${certificateResource.status.domainValidations[0].validationStatus == "SUCCESS" ? 
    certificateResource.status.ackResourceMetadata.arn : null}'
```