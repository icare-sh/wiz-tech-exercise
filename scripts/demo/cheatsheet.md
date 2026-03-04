# DEMO CHEATSHEET - Individual copy-paste commands

## Variables to set at the start
```bash
export AWS_REGION="us-east-1"
export MONGO_IP=$(cd ~/wiz-v2/wiz-tech-exercise/iac/envs/dev/ec2 && terraform output -raw mongo_public_ip)
export POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o jsonpath='{.items[0].metadata.name}')
export DETECTOR_ID=$(aws guardduty list-detectors --region $AWS_REGION --query "DetectorIds[0]" --output text)
```

---

## STAGE 1: Pipeline (show in GitHub UI)

Tabs to open:
- GitHub > Settings > Secrets (show there is NO AWS key)
- GitHub > Actions > "Security & Quality Check" (latest run)
- GitHub > Actions > "Production Release" (latest run with 3 jobs)

---

## STAGE 2: App + Kubernetes

### Cluster overview
```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### App pods + ingress
```bash
kubectl get pods -l app.kubernetes.io/name=wiz-exercise-app -o wide
kubectl get svc,ingress
```

### App URL
```bash
kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### MongoDB URI via env var (required by the exercise)
```bash
kubectl exec $POD_NAME -- env | grep MONGODB_URI
```

### wizexercise.txt (required by the exercise)
```bash
kubectl exec $POD_NAME -- cat /app/wizexercise.txt
```

### Cluster-admin proof (intentional weakness)
```bash
kubectl get clusterrolebinding wiz-app-wiz-exercise-app-admin -o yaml
kubectl auth can-i --list --as=system:serviceaccount:default:wiz-securelabs-app-sa | head -15
```

### SSH into MongoDB EC2
```bash
ssh -i ~/.ssh/mongo_key ubuntu@$MONGO_IP
```

### On the MongoDB EC2 (once connected via SSH)
```bash
# MongoDB version (4.4 = outdated)
mongod --version

# Ubuntu version (20.04 = outdated)
lsb_release -a

# Prove data is in the database
mongo admin -u admin -p '<password>' --eval "db.getSiblingDB('admin').todos.find().pretty()"

# Show the IAM role (AdministratorAccess)
aws sts get-caller-identity
aws iam list-attached-role-policies --role-name wiz-datastore-mongo-mongo-role
```

---

## STAGE 3: Cloud Security

### CloudTrail
```bash
aws cloudtrail describe-trails --region $AWS_REGION --query 'trailList[].{Name:Name,S3:S3BucketName,MultiRegion:IsMultiRegionTrail}' --output table
aws cloudtrail lookup-events --region $AWS_REGION --max-results 5 --query 'Events[].{Time:EventTime,User:Username,Action:EventName}' --output table
```

### AWS Config (NON_COMPLIANT = detections)
```bash
aws configservice describe-compliance-by-config-rule --region $AWS_REGION --query 'ComplianceByConfigRules[].{Rule:ConfigRuleName,Status:Compliance.ComplianceType}' --output table

# Open SSH detail
aws configservice get-compliance-details-by-config-rule --config-rule-name restricted-ssh --compliance-types NON_COMPLIANT --region $AWS_REGION --query 'EvaluationResults[].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId}' --output table

# Public S3 detail
aws configservice get-compliance-details-by-config-rule --config-rule-name s3-bucket-public-read-prohibited --compliance-types NON_COMPLIANT --region $AWS_REGION --query 'EvaluationResults[].{Resource:EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId}' --output table
```

### GuardDuty
```bash
aws guardduty list-findings --detector-id $DETECTOR_ID --region $AWS_REGION --max-results 5 --query 'FindingIds' --output json

# Finding detail (replace FINDING_ID)
aws guardduty get-findings --detector-id $DETECTOR_ID --finding-ids FINDING_ID --region $AWS_REGION --query 'Findings[].{Type:Type,Severity:Severity,Title:Title}' --output table
```

### Inspector (CVE)
```bash
aws inspector2 list-findings --region $AWS_REGION --filter-criteria '{"findingStatus":[{"comparison":"EQUALS","value":"ACTIVE"}]}' --max-results 5 --query 'findings[].{Title:title,Severity:severity}' --output table
```

### Password Policy
```bash
aws iam get-account-password-policy --query 'PasswordPolicy.{MinLength:MinimumPasswordLength,RequireLowercase:RequireLowercaseCharacters,RequireUppercase:RequireUppercaseCharacters,RequireNumbers:RequireNumbers,RequireSymbols:RequireSymbols}' --output table
```

### Falco
```bash
kubectl get pods -n falco
kubectl logs $(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}') -n falco --tail=20 | grep -i 'Warning\|Error'
```

### Trigger Falco live
```bash
kubectl exec $POD_NAME -- cat /etc/shadow
```

### Fail2ban (on EC2 via SSH)
```bash
# Check status
sudo fail2ban-client status sshd

# From your PC: trigger failures (another terminal)
for i in 1 2 3 4 5 6; do
  echo "Attempt $i..."
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 fakeuser@$MONGO_IP 2>&1 || true
done

# Re-check on EC2
sudo fail2ban-client status sshd
# -> You'll see your IP in the "Banned IP list"

# To unban yourself after the demo
sudo fail2ban-client set sshd unbanip <YOUR_IP>
```

---

## TABS TO OPEN BEFORE THE DEMO

1. **GitHub**: repo > Actions (CI + CD runs)
2. **Browser**: App URL (http://ALB_URL)
3. **AWS Console**:
   - CloudTrail > Event history
   - AWS Config > Rules
   - GuardDuty > Findings
   - Inspector > Findings
4. **Email**: GuardDuty + Falco emails received
5. **Terminal 1**: demo scripts
6. **Terminal 2**: SSH to MongoDB EC2
