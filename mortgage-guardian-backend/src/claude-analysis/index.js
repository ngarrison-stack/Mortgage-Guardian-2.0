const https = require('https');

exports.handler = async (event) => {
    console.log('Claude Analysis Function triggered');
    console.log('Event:', JSON.stringify(event, null, 2));

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    };

    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        // Parse request body
        const body = JSON.parse(event.body || '{}');
        const { document, analysisType = 'mortgage_audit' } = body;

        if (!document) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({
                    error: 'Document content is required',
                    message: 'Please provide document content for analysis'
                })
            };
        }

        // For now, return mock analysis data
        // TODO: Integrate with actual Claude API
        const mockAnalysis = {
            analysisId: `analysis_${Date.now()}`,
            timestamp: new Date().toISOString(),
            documentType: 'mortgage_statement',
            findings: [
                {
                    type: 'payment_discrepancy',
                    severity: 'high',
                    description: 'Principal payment amount does not match amortization schedule',
                    amount: 145.23,
                    location: 'Payment breakdown section'
                },
                {
                    type: 'escrow_calculation',
                    severity: 'medium',
                    description: 'Escrow analysis shows potential overpayment',
                    amount: 89.45,
                    location: 'Escrow account summary'
                }
            ],
            confidence: 0.87,
            recommendedActions: [
                'Request detailed payment breakdown from servicer',
                'File Notice of Error under RESPA Section 6',
                'Document all discrepancies for follow-up'
            ],
            aiSummary: 'Analysis indicates potential servicing errors in payment allocation and escrow calculations. Recommend immediate review with servicer.'
        };

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                analysis: mockAnalysis
            })
        };

    } catch (error) {
        console.error('Error in Claude Analysis:', error);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                error: 'Internal server error',
                message: 'Failed to process document analysis',
                details: process.env.NODE_ENV === 'development' ? error.message : undefined
            })
        };
    }
};