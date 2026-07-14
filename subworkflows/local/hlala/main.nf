include { RUN_HLALA } from '../../../modules/local/run_hlala'
//include { RUN_HLALA_PLACEHOLDER } from '../../../modules/local/run_hlala'
include { RUN_HLALA_PLACEHOLDER_SINGLE_END } from '../../../modules/local/run_hlala'
include { RUN_HLALA_PLACEHOLDER_FAILURE } from '../../../modules/local/run_hlala'

/*
workflow HLA_LA {
    take: 
    bam
    graphdir

    main:
    RUN_HLALA(
        bam,
        graphdir
    )
    // need to deal with two scenarios: 1. the user provides a single-end file (skip RUN_HLALA_PLACEHOLDER) 2. RUN_HLALA fails (ignore failure)
    // Determine who succeeded and who failed/skipped
    bam
        // Create a key-only channel [meta] to match against results
        //.map { meta, bam, bai -> meta }
        .map { meta, bam, bai -> [ meta ] } // wrap in list to make it a tuple key
        
        // Join with results. 'remainder: true' keeps keys even if results are missing.
        // Result format: [ meta, hlala_output_or_null ]
        .join(RUN_HLALA.out.hlala_call, remainder: true)
        
        // Split into two channels based on whether we got a result
        //.branch { meta, results ->
        //    success: results != null
        //        return [meta, results]  // Pass the file path
        //    failure: results == null
        //        return meta    // Pass just the meta for the placeholder
        .branch { item ->
        def meta = item[0]
        def results = item.size() > 1 ? item[1] : null

        success: results != null
            return [meta, results]

        failure: results == null
           return [meta, results]
        }
        .set { ch_routing }

    // Run placeholder for EVERYONE who didn't get a result
    // This includes Single-End (skipped) AND Paired-End (failed/ignored)
    RUN_HLALA_PLACEHOLDER(
        ch_routing.failure
    )

    // Merge results
    // We reconstruct the [meta, path] tuple for the success channel 
    // to match the placeholder output structure if needed, 
    // or just mix if structures align.
    
    // ch_routing.success looks like [path] or [meta, path] 
    // depending on exact join behavior. 
    // join(remainder:true) returns [key, val]. 
    // So ch_routing.success is [meta, path].

    emit:
    calls = ch_routing.success.mix(RUN_HLALA_PLACEHOLDER.out.hlala_call)
}
*/

/*workflow HLA_LA {

    take:
    bam
    graphdir

    main:

    RUN_HLALA(
        bam,
        graphdir
    )

    // create list of expected samples
    bam
        .map { meta, bam, index ->
            meta
        }
        .set { expected_samples }


    // successful HLA-LA
    RUN_HLALA.out.hlala_call
        .set { successful_hlala }


    // find samples without results
    expected_samples
        .join(
            successful_hlala.map { meta, result -> meta },
            remainder:true
        )
        .filter { meta, result -> result == null }
        .map { meta, result ->
            meta
        }
        .set { failed_hlala }


    RUN_HLALA_PLACEHOLDER(
        failed_hlala
    )


    emit:

    hlala_call =
        successful_hlala
        .mix(RUN_HLALA_PLACEHOLDER.out.hlala_call)
}
workflow HLA_LA {

    take:
    bam
    graphdir

    main:

    // Split paired-end and single-end samples
    bam
        .branch {
            paired: !it[0].single_end
            single: it[0].single_end
        }
        .set { hla_input }

    bam.view()
    // Run HLA-LA only on paired-end samples
    RUN_HLALA(
        hla_input.paired,
        graphdir
    )


    // Generate NA output for single-end samples
    RUN_HLALA_PLACEHOLDER(
        hla_input.single.map { meta, bam, index -> meta }
    )


    emit:

    hlala_call = RUN_HLALA.out.hlala_call
        .mix(RUN_HLALA_PLACEHOLDER.out.hlala_call)
}
*/
workflow HLA_LA {

    take:
    bam
    graphdir

    main:

    RUN_HLALA(
        bam,
        graphdir
    )


    // Expected samples: keep only key
    bam
        .map { meta, bam, index ->
            [meta.sample, meta]
        }
        .set { expected_samples }


    // Successful HLA-LA outputs
    RUN_HLALA.out.hlala_call
        .map { meta, result ->
            [meta.sample, result]
        }
        .set { successful_hlala }


    // Find missing samples
    expected_samples
        .join(successful_hlala, remainder:true)
        .filter { sample, meta, result ->
            result == null
        }
        .map { sample, meta, result ->
            meta
        }
        .branch {
            paired: it.single_end == false
            single: it.single_end == true
        }
        .set { failed_hlala }

    failed_hlala_single = failed_hlala.single
    failed_hlala_paired = failed_hlala.paired
    failed_hlala_single.view()

    RUN_HLALA_PLACEHOLDER_SINGLE_END(
        failed_hlala.single
    )

    RUN_HLALA_PLACEHOLDER_FAILURE(
        failed_hlala.paired
    )
    
    emit:

    hlala_call =
        RUN_HLALA.out.hlala_call
        .mix(RUN_HLALA_PLACEHOLDER_SINGLE_END.out.hlala_call)
        .mix(RUN_HLALA_PLACEHOLDER_FAILURE.out.hlala_call)
    
}
